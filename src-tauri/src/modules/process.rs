use std::path::{Path, PathBuf};
use std::process::Command;
use std::thread;
use std::time::Duration;
use std::fs;

// Import local modules
use crate::modules::files::{data_dir, ensure_config, config_path};
use crate::modules::utils::resolve_bin;
use crate::modules::commands::run_cli;

#[tauri::command]
pub fn start_node() -> Result<(), String> {
  let cfg = ensure_config()?;
  let dir = data_dir()?;
  let daemon = resolve_bin("hemp0xd");
  let daemon_path = PathBuf::from(&daemon);
  if !daemon_path.exists() {
    return Err(format!("Daemon not found at {}", daemon));
  }
  let mut cmd = Command::new(&daemon);
  if let Some(parent) = daemon_path.parent() {
    cmd.current_dir(parent);
  }
  #[cfg(windows)]
  {
    use std::os::windows::process::CommandExt;
    cmd.creation_flags(0x08000000); // CREATE_NO_WINDOW
  }
  cmd
    .arg(format!("-conf={}", cfg.to_string_lossy()))
    .arg(format!("-datadir={}", dir.to_string_lossy()));
  if !cfg!(windows) {
    cmd.arg("-daemon");
  }
  cmd
    .spawn()
    .map_err(|e| e.to_string())?;
  Ok(())
}

#[tauri::command]
pub fn stop_node() -> Result<(), String> {
  let _ = run_cli(&[String::from("stop")])?;
  Ok(())
}

#[tauri::command]
pub fn set_network_mode(mode: String) -> Result<String, String> {
  // Attempt to stop the running node BEFORE changing config
  let _ = stop_node(); 
  
  // Give it a moment to shutdown gracefully
  thread::sleep(Duration::from_secs(2));

  let cfg_path = config_path()?;
  ensure_config()?; // Ensure it exists

  let content = fs::read_to_string(&cfg_path).map_err(|e| e.to_string())?;
  let mut new_lines: Vec<String> = Vec::new();

  // Filter out existing network flags
  for line in content.lines() {
    if !line.trim().starts_with("testnet=") && !line.trim().starts_with("regtest=") {
      new_lines.push(line.to_string());
    }
  }

  // Add new mode
  match mode.as_str() {
    "testnet" => new_lines.push("testnet=1".to_string()),
    "regtest" => new_lines.push("regtest=1".to_string()),
    "mainnet" => {}, // distinct absence of flags
    _ => return Err("Invalid network mode".to_string()),
  }

  // Write back
  fs::write(&cfg_path, new_lines.join("\n")).map_err(|e| e.to_string())?;
  Ok("Network mode updated. Please restart the node.".to_string())
}

#[tauri::command]
pub fn restart_app(app_handle: tauri::AppHandle) {
  app_handle.restart();
}

// Helper for restore_wallet and create_new_wallet
pub fn wait_for_lock_release(dir: &Path) {
  let lock_path = dir.join(".lock");
  for _ in 0..20 {
    if !lock_path.exists() {
      break;
    }
    thread::sleep(Duration::from_millis(500));
  }
}

pub fn stop_node_internal() {
    let _ = run_cli(&[String::from("stop")]);
    thread::sleep(Duration::from_secs(2));
}

#[tauri::command]
pub fn restore_wallet(path: String, backup_existing: bool, restart_node: bool) -> Result<(), String> {
  let dir = data_dir()?;
    let wallet = dir.join("wallet.dat");
    if !Path::new(&path).exists() {
      return Err("Restore file not found.".to_string());
    }
    
    // Stop node logic internal
    stop_node_internal();
    
    if wallet.exists() && backup_existing {
      let ts = chrono::Local::now().format("%Y%m%d_%H%M%S").to_string();
      let backup_dir = dir.join("wallet_backups");
      let _ = fs::create_dir_all(&backup_dir);
      let backup = backup_dir.join(format!("wallet_{}.bak", ts));
      fs::rename(&wallet, backup).map_err(|e| e.to_string())?;
    } else if wallet.exists() {
      fs::remove_file(&wallet).map_err(|e| e.to_string())?;
    }
    fs::copy(path, wallet).map_err(|e| e.to_string())?;
  if restart_node {
    wait_for_lock_release(&dir);
    let _ = start_node();
  }
  Ok(())
}

#[tauri::command]
pub fn create_new_wallet(backup_existing: bool, restart_node: bool) -> Result<(), String> {
  let dir = data_dir()?;
    let wallet = dir.join("wallet.dat");
    
    stop_node_internal();
    
    if wallet.exists() && backup_existing {
      let ts = chrono::Local::now().format("%Y%m%d_%H%M%S").to_string();
      let backup_dir = dir.join("wallet_backups");
      let _ = fs::create_dir_all(&backup_dir);
      let backup = backup_dir.join(format!("wallet_{}.bak", ts));
      fs::rename(&wallet, backup).map_err(|e| e.to_string())?;
    } else if wallet.exists() {
      fs::remove_file(&wallet).map_err(|e| e.to_string())?;
    }
  if restart_node {
    wait_for_lock_release(&dir);
    let _ = start_node();
  }
  Ok(())
}

// Commands from commands.rs that also need start/stop access, i.e., backup_wallet is fine in commands.rs
// restore/create_wallet involve restarting logic so they moved here.
