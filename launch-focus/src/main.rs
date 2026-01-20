use objc2::rc::Retained;
use objc2_app_kit::{NSApplicationActivationOptions, NSRunningApplication, NSWorkspace};
use serde::Deserialize;
use std::env;
use std::fs;
use std::io::{BufRead, BufReader, Read, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::process::Command;

const SOCKET_PATH: &str = "/tmp/launch-focus.sock";

#[derive(Deserialize)]
struct Window {
    id: u32,
    app: String,
    #[serde(rename = "is-minimized")]
    is_minimized: bool,
}

// Use yabai socket for window queries (fast, ~5ms)
fn yabai_query(msg: &str) -> Option<String> {
    let user = env::var("USER").ok()?;
    let socket_path = format!("/tmp/yabai_{}.socket", user);

    let mut stream = UnixStream::connect(&socket_path).ok()?;
    stream.write_all(msg.as_bytes()).ok()?;

    let mut response = String::new();
    stream.read_to_string(&mut response).ok()?;
    Some(response)
}

fn get_focused_window() -> Option<Window> {
    let response = yabai_query("query --windows --window")?;
    serde_json::from_str(&response).ok()
}

fn get_app_windows(app: &str) -> Vec<Window> {
    let response = match yabai_query("query --windows") {
        Some(r) => r,
        None => return vec![],
    };

    let windows: Vec<Window> = match serde_json::from_str(&response) {
        Ok(w) => w,
        Err(_) => return vec![],
    };

    windows
        .into_iter()
        .filter(|w| w.app == app && !w.is_minimized)
        .collect()
}

fn focus_window(id: u32) {
    let _ = yabai_query(&format!("window --focus {}", id));
}

// Use native NSWorkspace for app activation (fast, no osascript)
fn get_frontmost_app() -> Option<String> {
    let workspace = NSWorkspace::sharedWorkspace();
    let app = workspace.frontmostApplication()?;
    let name = app.localizedName()?;
    Some(name.to_string())
}

#[allow(deprecated)]  // ActivateIgnoringOtherApps deprecated in macOS 14 but still works
fn activate_app_native(app_name: &str) -> bool {
    let workspace = NSWorkspace::sharedWorkspace();
    let apps = workspace.runningApplications();

    // Try to activate if already running
    for i in 0..apps.count() {
        let app: Retained<NSRunningApplication> = unsafe {
            Retained::cast_unchecked(apps.objectAtIndex(i))
        };
        if let Some(name) = app.localizedName() {
            if name.to_string() == app_name {
                let options = NSApplicationActivationOptions::ActivateIgnoringOtherApps;
                return app.activateWithOptions(options);
            }
        }
    }
    false
}

// Launch app if not running (uses `open -a`)
fn launch_app(app_name: &str) -> bool {
    eprintln!("[LAUNCH] opening app: {}", app_name);
    Command::new("open")
        .args(["-a", app_name])
        .spawn()
        .is_ok()
}

fn handle_launch(target_app: &str) {
    eprintln!("[REQ] target_app={:?}", target_app);

    let current = get_focused_window();
    let current_app = current.as_ref().map(|w| w.app.as_str());
    let windows = get_app_windows(target_app);

    eprintln!("[STATE] current_app={:?}, windows_count={}", current_app, windows.len());

    if current_app == Some(target_app) {
        // Already focused - cycle to next window
        eprintln!("[ACTION] cycling windows");
        if windows.len() > 1 {
            if let Some(current_window) = current {
                if let Some(idx) = windows.iter().position(|w| w.id == current_window.id) {
                    let next_idx = (idx + 1) % windows.len();
                    focus_window(windows[next_idx].id);
                    eprintln!("[DONE] focused window {}", windows[next_idx].id);
                }
            }
        }
    } else if let Some(w) = windows.first() {
        // App has windows - use yabai focus (fast)
        eprintln!("[ACTION] yabai focus window {}", w.id);
        focus_window(w.id);
    } else {
        // App not running or no windows - try native activation first
        eprintln!("[ACTION] native activate");
        let result = activate_app_native(target_app);
        eprintln!("[RESULT] activate={}", result);

        if !result {
            // App not running - launch it
            launch_app(target_app);
        } else {
            // Re-query for windows after activation
            let windows = get_app_windows(target_app);
            if let Some(w) = windows.first() {
                focus_window(w.id);
            }
        }
    }
}

fn run_daemon() {
    let _ = fs::remove_file(SOCKET_PATH);

    let listener = match UnixListener::bind(SOCKET_PATH) {
        Ok(l) => l,
        Err(e) => {
            eprintln!("Failed to bind socket: {}", e);
            std::process::exit(1);
        }
    };

    eprintln!("launch-focus daemon v0.2 (yabai + native NSWorkspace) on {}", SOCKET_PATH);

    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                let mut reader = BufReader::new(&stream);
                let mut line = String::new();
                if reader.read_line(&mut line).is_ok() {
                    let app = line.trim();
                    if !app.is_empty() {
                        handle_launch(app);
                    }
                }
            }
            Err(e) => eprintln!("Connection error: {}", e),
        }
    }
}

fn send_to_daemon(app: &str) -> Result<(), std::io::Error> {
    let mut stream = UnixStream::connect(SOCKET_PATH)?;
    writeln!(stream, "{}", app)?;
    Ok(())
}

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        eprintln!("Usage: launch-focus <App Name>");
        eprintln!("       launch-focus --daemon");
        std::process::exit(1);
    }

    match args[1].as_str() {
        "--daemon" => run_daemon(),
        target_app => {
            if send_to_daemon(target_app).is_err() {
                handle_launch(target_app);
            }
        }
    }
}
