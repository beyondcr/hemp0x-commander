use chrono::{DateTime, Local, TimeZone};
use rand::Rng;
use serde::Serialize;
use std::collections::HashMap;
use std::fs;
use std::io::{Read, Seek, SeekFrom};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::{Mutex, OnceLock};
use std::thread;
use std::time::Duration;
use uuid::Uuid;
#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;
#[cfg(windows)]
use std::os::windows::process::CommandExt;

#[derive(Serialize)]
struct NodeInfo {
  state: String,
  blocks: u64,
  headers: u64,
  peers: u64,
  diff: String,
  synced: bool,
}

#[derive(Serialize)]
struct WalletInfo {
  balance: String,
  pending: String,
  staked: String,
  status: String,
}

#[derive(Serialize)]
struct TxItem {
  date: String,
  #[serde(rename = "type")]
  tx_type: String,
  amount: String,
  conf: u64,
  txid: String,
}

#[derive(Serialize)]
struct DashboardData {
  node: NodeInfo,
  wallet: WalletInfo,
  tx: Vec<TxItem>,
}

#[derive(Serialize)]
struct ConfigPaths {
  data_dir: String,
  config_path: String,
  daemon_path: String,
  cli_path: String,
}

#[derive(Serialize)]
struct BinaryStatus {
  daemon_exists: bool,
  cli_exists: bool,
}

#[derive(Serialize)]
struct AddressItem {
  label: String,
  address: String,
  balance: String,
}

#[derive(Serialize)]
struct AssetItem {
  name: String,
  balance: String,
  #[serde(rename = "type")]
  asset_type: String,
}

#[derive(Serialize, serde::Deserialize)]
struct UtxoItem {
  txid: String,
  vout: u64,
  address: Option<String>,
  amount: f64,
  confirmations: u64,
  spendable: Option<bool>,
  solvable: Option<bool>,
  desc: Option<String>,
  safe: Option<bool>,
}

fn data_dir() -> Result<PathBuf, String> {
  if cfg!(windows) {
    let appdata = std::env::var("APPDATA").map_err(|_| "APPDATA not set".to_string())?;
    Ok(PathBuf::from(appdata).join("Hemp0x"))
  } else {
    let home = dirs::home_dir().ok_or("HOME not set")?;
    Ok(home.join(".hemp0x"))
  }
}

fn config_path() -> Result<PathBuf, String> {
  Ok(data_dir()?.join("hemp.conf"))
}

fn bin_name(name: &str) -> String {
  if cfg!(windows) {
    format!("{name}.exe")
  } else {
    name.to_string()
  }
}

fn add_bin_candidates(candidates: &mut Vec<PathBuf>, base: PathBuf, name: &str, depth: usize) {
  let mut current = Some(base);
  for _ in 0..=depth {
    if let Some(path) = current {
      candidates.push(path.join(bin_name(name)));
      current = path.parent().map(|p| p.to_path_buf());
    } else {
      break;
    }
  }
}

fn resolve_bin(name: &str) -> String {
  // Tauri Sidecar logic attempts to append target triple, e.g., name-x86_64-unknown-linux-gnu
  // But since we are manually handling paths or using externalBin without sidecar renaming script sometimes,
  // we check the standard locations where Tauri places external binaries.
  
  if let Ok(exe) = std::env::current_exe() {
    if let Some(dir) = exe.parent() {
      // 1. Check same directory as executable (Tauri default for AppImage/portable)
      let candidate = dir.join(bin_name(name));
      if candidate.exists() {
         return candidate.to_string_lossy().to_string();
      }
      
      // 2. Check "resources" or "bin" subdirectories (common bundling patterns)
      let resources = dir.join("resources").join(bin_name(name));
      if resources.exists() {
        return resources.to_string_lossy().to_string();
      }
    }
  }

  // 3. Dev/Manual Fallback: classic search logic
  let mut candidates: Vec<PathBuf> = Vec::new();
  if let Ok(cwd) = std::env::current_dir() {
    add_bin_candidates(&mut candidates, cwd, name, 4);
  }
  
  let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
  add_bin_candidates(&mut candidates, manifest_dir, name, 5);
  
  if !cfg!(windows) {
    if let Some(home) = dirs::home_dir() {
      let candidate = home
        .join("hemp0x-deploy")
        .join("hemp0x-core")
        .join("src")
        .join(bin_name(name));
      candidates.push(candidate);
    }
  }
  
  for candidate in candidates {
    if candidate.exists() {
      return candidate.to_string_lossy().to_string();
    }
  }
  
  // Return bare name to rely on PATH if all else fails
  name.to_string()
}

#[tauri::command]
fn get_binary_status() -> Result<BinaryStatus, String> {
  let daemon_path = PathBuf::from(resolve_bin("hemp0xd"));
  let cli_path = PathBuf::from(resolve_bin("hemp0x-cli"));
  Ok(BinaryStatus {
    daemon_exists: daemon_path.exists(),
    cli_exists: cli_path.exists(),
  })
}

#[derive(Default)]
struct ShellState {
  cwd: PathBuf,
}

static SHELL_STATE: OnceLock<Mutex<ShellState>> = OnceLock::new();

fn default_shell_cwd() -> PathBuf {
  let candidate = PathBuf::from(resolve_bin("hemp0xd"));
  if candidate.exists() {
    if let Some(parent) = candidate.parent() {
      return parent.to_path_buf();
    }
  }
  std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."))
}

fn shell_state() -> &'static Mutex<ShellState> {
  SHELL_STATE.get_or_init(|| Mutex::new(ShellState { cwd: default_shell_cwd() }))
}

fn ensure_config() -> Result<PathBuf, String> {
  let dir = data_dir()?;
  let cfg = config_path()?;
  if !dir.exists() {
    fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
  }
  if !cfg.exists() {
    let rpc_user = format!("u{}", rand::thread_rng().gen_range(10000..99999));
    let rpc_pass = Uuid::new_v4();
    let daemon_flag = "0";
    let content = format!(
      "rpcuser={}\nrpcpassword={}\nserver=1\ndaemon={}\naddnode=154.38.164.123:42069\naddnode=144.202.3.215:42069\n",
      rpc_user, rpc_pass, daemon_flag
    );
    fs::write(&cfg, content).map_err(|e| e.to_string())?;
  }
  Ok(cfg)
}

fn parse_config(path: &Path) -> Result<HashMap<String, String>, String> {
  let content = fs::read_to_string(path).map_err(|e| e.to_string())?;
  let mut map = HashMap::new();
  for line in content.lines() {
    let line = line.trim();
    if line.is_empty() || line.starts_with('#') {
      continue;
    }
    if let Some((k, v)) = line.split_once('=') {
      map.insert(k.trim().to_string(), v.trim().to_string());
    }
  }
  Ok(map)
}

fn run_cli(args: &[String]) -> Result<String, String> {
  let cfg = ensure_config()?;
  let dir = data_dir()?;
  let cli = resolve_bin("hemp0x-cli");
  let cli_path = PathBuf::from(&cli);
  if !cli_path.exists() {
    return Err(format!("CLI not found at {}", cli));
  }
  let mut cmd = Command::new(&cli);
  if let Some(parent) = cli_path.parent() {
    cmd.current_dir(parent);
  }
  #[cfg(windows)]
  {
    cmd.creation_flags(0x08000000); // CREATE_NO_WINDOW
  }
  let output = cmd
    .arg(format!("-conf={}", cfg.to_string_lossy()))
    .arg(format!("-datadir={}", dir.to_string_lossy()))
    .args(args.iter().map(|v| v.as_str()))
    .output()
    .map_err(|e| e.to_string())?;
  if !output.status.success() {
    let err = String::from_utf8_lossy(&output.stderr);
    let out = String::from_utf8_lossy(&output.stdout);
    return Err(format!(
      "CLI error ({}): {} {}",
      output.status,
      err.trim(),
      out.trim()
    )
    .trim()
    .to_string());
  }
  let out = String::from_utf8_lossy(&output.stdout);
  Ok(out.trim().to_string())
}

#[tauri::command]
fn run_shell_command(command: String) -> Result<String, String> {
  let line_raw = command.trim();
  if line_raw.is_empty() {
    return Err("Empty command".to_string());
  }

  let mut line = line_raw.to_string();
  if cfg!(windows) {
    let trimmed = line_raw.trim();
    if trimmed == "ls" {
      line = "dir".to_string();
    } else if trimmed.starts_with("ls ") {
      line = format!("dir {}", trimmed[3..].trim());
    } else if trimmed == "pwd" {
      line = "cd".to_string();
    } else if trimmed.starts_with("cat ") {
      line = format!("type {}", trimmed[4..].trim());
    } else if trimmed.starts_with("rm -rf ") || trimmed.starts_with("rm -r ") {
      line = format!("rmdir /s /q {}", trimmed[6..].trim());
    } else if trimmed.starts_with("rm ") {
      line = format!("del /q {}", trimmed[3..].trim());
    }
  }

  let mut state = shell_state()
    .lock()
    .map_err(|_| "Shell state unavailable".to_string())?;
  let current = state.cwd.clone();
  let lower = line.to_lowercase();

  if lower == "cd"
    || lower.starts_with("cd ")
    || lower.starts_with("cd\t")
    || lower.starts_with("cd /d ")
    || lower.starts_with("cd /d\t")
    || lower.starts_with("cd /D ")
    || lower.starts_with("cd /D\t")
  {
    let mut arg = line[2..].trim();
    if arg.to_lowercase().starts_with("/d ") || arg.to_lowercase().starts_with("/d\t") {
      arg = arg[2..].trim();
    }
    if arg.is_empty() {
      return Ok(current.to_string_lossy().to_string());
    }
    let mut cleaned = arg.trim();
    if cleaned.starts_with('"') && cleaned.ends_with('"') && cleaned.len() > 1 {
      cleaned = &cleaned[1..cleaned.len() - 1];
    }
    let mut new_path = PathBuf::from(cleaned);
    if !new_path.is_absolute() {
      new_path = current.join(new_path);
    }
    if !new_path.exists() {
      return Err(format!("Directory not found: {}", new_path.display()));
    }
    let canonical = fs::canonicalize(&new_path).unwrap_or(new_path);
    state.cwd = canonical.clone();
    return Ok(canonical.to_string_lossy().to_string());
  }

  let cwd = if current.exists() {
    current
  } else {
    std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."))
  };
  state.cwd = cwd.clone();
  let output = if cfg!(windows) {
    Command::new("cmd")
      .current_dir(&cwd)
      .args(&["/C", &line])
      .output()
  } else {
    Command::new("bash")
      .current_dir(&cwd)
      .args(&["-lc", &line])
      .output()
  }
  .map_err(|e| e.to_string())?;

  let mut text = String::new();
  if !output.stdout.is_empty() {
    text.push_str(&String::from_utf8_lossy(&output.stdout));
  }
  if !output.stderr.is_empty() {
    if !text.is_empty() {
      text.push('\n');
    }
    text.push_str(&String::from_utf8_lossy(&output.stderr));
  }

  if output.status.success() {
    if text.trim().is_empty() {
      Ok("(no output)".to_string())
    } else {
      Ok(text.trim_end().to_string())
    }
  } else if text.trim().is_empty() {
    Err("Command failed".to_string())
  } else {
    Err(text.trim_end().to_string())
  }
}

#[tauri::command]
fn shell_autocomplete(line: String) -> Result<Vec<String>, String> {
  let mut state = shell_state()
    .lock()
    .map_err(|_| "Shell state unavailable".to_string())?;
  let cwd = if state.cwd.exists() {
    state.cwd.clone()
  } else {
    std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."))
  };
  state.cwd = cwd.clone();

  let trimmed = line.trim_end();
  let mut prefix = trimmed.split_whitespace().last().unwrap_or("").to_string();
  if prefix.starts_with('"') {
    prefix = prefix.trim_start_matches('"').to_string();
  }
  let prefix_cmp = if cfg!(windows) {
    prefix.to_lowercase()
  } else {
    prefix.clone()
  };

  let mut matches = Vec::new();
  let entries = fs::read_dir(&cwd).map_err(|e| e.to_string())?;
  for entry in entries.flatten() {
    let name = entry.file_name().to_string_lossy().to_string();
    let candidate_cmp = if cfg!(windows) {
      name.to_lowercase()
    } else {
      name.clone()
    };
    if prefix_cmp.is_empty() || candidate_cmp.starts_with(&prefix_cmp) {
      matches.push(name);
    }
  }
  matches.sort();
  Ok(matches)
}

fn parse_balances(value: &serde_json::Value, map: &mut HashMap<String, f64>) {
  if let Some(arr) = value.as_array() {
    for item in arr {
      if let Some(row) = item.as_array() {
        if row.len() >= 2 {
          if let (Some(addr), Some(amount)) = (row[0].as_str(), row[1].as_f64()) {
            map.insert(addr.to_string(), amount);
          }
        }
        parse_balances(item, map);
      }
    }
  }
}

fn split_args(input: &str) -> Vec<String> {
  let mut args = Vec::new();
  let mut current = String::new();
  let mut in_quotes = false;
  let mut quote_char = '\0';
  let mut chars = input.chars().peekable();
  while let Some(ch) = chars.next() {
    if in_quotes {
      if ch == quote_char {
        in_quotes = false;
      } else if ch == '\\' {
        if let Some(next) = chars.next() {
          current.push(next);
        }
      } else {
        current.push(ch);
      }
    } else if ch == '"' || ch == '\'' {
      in_quotes = true;
      quote_char = ch;
    } else if ch.is_whitespace() {
      if !current.is_empty() {
        args.push(current.clone());
        current.clear();
      }
    } else {
      current.push(ch);
    }
  }
  if !current.is_empty() {
    args.push(current);
  }
  args
}

fn read_log_tail(path: &Path, max_lines: usize) -> Result<String, String> {
  if !path.exists() {
    return Ok(String::from("Log file not found."));
  }
  let mut file = fs::File::open(path).map_err(|e| e.to_string())?;
  let size = file.metadata().map_err(|e| e.to_string())?.len();
  let read_size = std::cmp::min(size, 2 * 1024 * 1024);
  file
    .seek(SeekFrom::End(-(read_size as i64)))
    .map_err(|e| e.to_string())?;
  let mut buf = String::new();
  file.read_to_string(&mut buf).map_err(|e| e.to_string())?;
  let lines: Vec<&str> = buf.lines().collect();
  let start = lines.len().saturating_sub(max_lines);
  Ok(lines[start..].join("\n"))
}

#[tauri::command]
fn init_config() -> Result<ConfigPaths, String> {
  let cfg = ensure_config()?;
  let dir = data_dir()?;
  Ok(ConfigPaths {
    data_dir: dir.to_string_lossy().to_string(),
    config_path: cfg.to_string_lossy().to_string(),
    daemon_path: resolve_bin("hemp0xd"),
    cli_path: resolve_bin("hemp0x-cli"),
  })
}

#[tauri::command]
fn dashboard_data() -> Result<DashboardData, String> {
  let cfg = ensure_config()?;
  let _ = parse_config(&cfg)?;

  // OPTIMIZATION: Check if process is running before invoking CLI
  // This prevents heavy process-spawn/timeout lag when node is stopped.
  let mut is_running = true;

  #[cfg(unix)]
  {
    use std::process::Command;
    // pgrep returns exit code 0 if found, 1 if not.
    // We check for 'hemp0xd' strictly.
    let output = Command::new("pgrep")
        .arg("-x") // exact match
        .arg("hemp0xd")
        .output();
    
    if let Ok(o) = output {
        if !o.status.success() {
            is_running = false;
        }
    } else {
        // If pgrep fails to run, assume false or fallback? 
        // Safer to assume false to force 'Starting' logic if unsure, 
        // OR true to let run_cli try.
        // Let's assume true if pgrep command notably fails, BUT 
        // if pgrep runs and returns !success, it means Not Found.
    }
  }

  #[cfg(windows)]
  {
    let output = Command::new("tasklist")
      .creation_flags(0x08000000) // CREATE_NO_WINDOW
      .arg("/FI")
      .arg("IMAGENAME eq hemp0xd.exe")
      .arg("/NH") // No Header
      .output();
    
    if let Ok(o) = output {
        let stdout = String::from_utf8_lossy(&o.stdout);
        // If it doesn't contain the exe name, it's not running
        if !stdout.contains("hemp0xd.exe") {
            is_running = false;
        }
    }
  }

  // Fast fail if not running
  if !is_running {
     return Ok(DashboardData {
        node: NodeInfo {
            state: "OFFLINE".to_string(),
            blocks: 0,
            headers: 0,
            peers: 0,
            diff: "--".to_string(),
            synced: false,
        },
        wallet: WalletInfo {
            balance: "--".to_string(),
            pending: "--".to_string(),
            staked: "--".to_string(),
            status: "--".to_string(),
        },
        tx: Vec::new(),
     });
  }

  let info_raw = run_cli(&[String::from("getinfo")])?;
  let info: serde_json::Value = serde_json::from_str(&info_raw).map_err(|e| e.to_string())?;

  let blocks_info = info["blocks"].as_u64().unwrap_or(0);
  let peers = info["connections"].as_u64().unwrap_or(0);
  let diff_val = info["difficulty"].as_f64().unwrap_or(0.0);
  let balance_val = info["balance"].as_f64().unwrap_or(0.0);
  let pending_val = info["unconfirmed_balance"].as_f64().unwrap_or(0.0);
  let staked_val = info["immature_balance"].as_f64().unwrap_or(0.0);

  let unlocked_until = info["unlocked_until"].as_i64();
  let status = match unlocked_until {
    Some(0) => "LOCKED",
    Some(_) => "UNLOCKED",
    None => "UNENCRYPTED",
  };

  // Fetch blockchain info for sync status and canonical block height
  let (blocks, headers, synced) = match run_cli(&[String::from("getblockchaininfo")]) {
    Ok(bc_raw) => {
      if let Ok(bc_info) = serde_json::from_str::<serde_json::Value>(&bc_raw) {
        let b = bc_info["blocks"].as_u64().unwrap_or(blocks_info);
        let h = bc_info["headers"].as_u64().unwrap_or(0);
        let progress = bc_info["verificationprogress"].as_f64().unwrap_or(0.0);
        let initial_dl = bc_info["initialblockdownload"].as_bool().unwrap_or(false);
        let mtp = bc_info["mediantime"].as_i64().unwrap_or(0);
        let now = Local::now().timestamp();
        // Synced if: headers known, blocks >= headers, progress high, not IBD, and MTP within 90 mins (avoids stall false positives)
        let is_synced = h > 0 && b >= h && progress >= 0.999 && !initial_dl && (now - mtp) < 5400;
        (b, h, is_synced)
      } else {
        (blocks_info, blocks_info, false) // Fallback: unknown sync status
      }
    }
    Err(_) => (blocks_info, blocks_info, false) // Fallback: unknown sync status
  };

  let node = NodeInfo {
    state: "RUNNING".to_string(),
    blocks,
    headers,
    peers,
    diff: format!("{:.4}", diff_val),
    synced,
  };

  let wallet = WalletInfo {
    balance: format!("{:.3}", balance_val),
    pending: format!("{:.3}", pending_val),
    staked: format!("{:.3}", staked_val),
    status: status.to_string(),
  };

  let tx_raw = run_cli(&[
    String::from("listtransactions"),
    String::from("*"),
    String::from("100"),
  ])?;
  let tx_list: serde_json::Value = serde_json::from_str(&tx_raw).map_err(|e| e.to_string())?;
  let mut txs = Vec::new();
  let mut tx_vec: Vec<serde_json::Value> = tx_list.as_array().unwrap_or(&Vec::new()).clone();
  tx_vec.sort_by(|a, b| {
    let time_a = a["time"].as_i64().unwrap_or(0);
    let time_b = b["time"].as_i64().unwrap_or(0);
    if time_a != time_b {
      return time_a.cmp(&time_b);
    }
    // Time equal: Logical sort (send < receive) -> Send is Older
    let cat_a = a["category"].as_str().unwrap_or("");
    let cat_b = b["category"].as_str().unwrap_or("");
    if cat_a == "send" && cat_b == "receive" {
      return std::cmp::Ordering::Less;
    }
    if cat_a == "receive" && cat_b == "send" {
      return std::cmp::Ordering::Greater;
    }
    cat_a.cmp(cat_b)
  });

  for tx in tx_vec.iter().rev().take(50) {
      let epoch = tx["time"].as_i64().unwrap_or(0);
      let dt: DateTime<Local> = Local.timestamp_opt(epoch, 0).single().unwrap_or_else(|| Local::now());
      let amount = tx["amount"].as_f64().unwrap_or(0.0);
      let item = TxItem {
        date: dt.format("%m/%d %H:%M").to_string(),
        tx_type: tx["category"].as_str().unwrap_or("unknown").to_string(),
        amount: format!("{:.7}", amount),
        conf: tx["confirmations"].as_u64().unwrap_or(0),
        txid: tx["txid"].as_str().unwrap_or("-").to_string(),
      };
      txs.push(item);
  }

  Ok(DashboardData {
    node,
    wallet,
    tx: txs,
  })
}

#[tauri::command]
fn start_node() -> Result<(), String> {
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
fn stop_node() -> Result<(), String> {
  let _ = run_cli(&[String::from("stop")])?;
  Ok(())
}

#[tauri::command]
fn get_receive_addresses(show_change: bool) -> Result<Vec<AddressItem>, String> {
  ensure_config()?;

  let groups_raw = run_cli(&[String::from("listaddressgroupings")])?;
  let groups: serde_json::Value =
    serde_json::from_str(&groups_raw).map_err(|e| e.to_string())?;
  let mut balances = HashMap::new();
  parse_balances(&groups, &mut balances);

  let list_raw = run_cli(&[
    String::from("listreceivedbyaddress"),
    String::from("0"),
    String::from("true"),
  ])?;
  let list: serde_json::Value = serde_json::from_str(&list_raw).map_err(|e| e.to_string())?;

  let mut items = Vec::new();
  let mut seen = HashMap::new();
  if let Some(arr) = list.as_array() {
    for item in arr {
      let addr = item["address"].as_str().unwrap_or("").to_string();
      if addr.is_empty() {
        continue;
      }
      let label = item["label"]
        .as_str()
        .or(item["account"].as_str())
        .unwrap_or("")
        .to_string();
      let bal = balances.get(&addr).copied().unwrap_or(0.0);
      items.push(AddressItem {
        label,
        address: addr.clone(),
        balance: format!("{:.8}", bal),
      });
      seen.insert(addr, true);
    }
  }

  if show_change {
    for (addr, bal) in balances {
      if !seen.contains_key(&addr) {
        items.push(AddressItem {
          label: "(Change)".to_string(),
          address: addr,
          balance: format!("{:.8}", bal),
        });
      }
    }
  }

  Ok(items)
}

#[tauri::command]
fn new_address(label: Option<String>) -> Result<String, String> {
  ensure_config()?;
  match label {
    Some(l) if !l.trim().is_empty() => run_cli(&[String::from("getnewaddress"), l]),
    _ => run_cli(&[String::from("getnewaddress")]),
  }
}

#[tauri::command]
fn get_change_address() -> Result<String, String> {
  ensure_config()?;
  run_cli(&[String::from("getrawchangeaddress")])
}

#[tauri::command]
fn get_network_mode() -> Result<String, String> {
  let cfg_path = config_path()?;
  if !cfg_path.exists() {
    return Ok("mainnet".to_string());
  }

  let content = fs::read_to_string(&cfg_path).map_err(|e| e.to_string())?;
  let mut is_testnet = false;
  let mut is_regtest = false;

  for line in content.lines() {
    let line = line.trim();
    if line.starts_with("testnet=1") {
      is_testnet = true;
    } else if line.starts_with("regtest=1") {
      is_regtest = true;
    }
  }

  if is_regtest {
    Ok("regtest".to_string())
  } else if is_testnet {
    Ok("testnet".to_string())
  } else {
    Ok("mainnet".to_string())
  }
}

#[tauri::command]
fn set_network_mode(mode: String) -> Result<String, String> {
  // Attempt to stop the running node BEFORE changing config
  // (So the 'stop' command goes to the correct network port currently running)
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
fn restart_app(app_handle: tauri::AppHandle) {
  app_handle.restart();
}

#[tauri::command]
fn send_hemp(to: String, amount: String) -> Result<String, String> {
  ensure_config()?;
  run_cli(&[String::from("sendtoaddress"), to, amount])
}

#[tauri::command]
fn list_assets() -> Result<Vec<AssetItem>, String> {
  ensure_config()?;
  let raw = run_cli(&[String::from("listmyassets")])?;
  let value: serde_json::Value = serde_json::from_str(&raw).map_err(|e| e.to_string())?;
  let mut items = Vec::new();
  if let Some(obj) = value.as_object() {
    for (name, bal) in obj {
      let amount = bal.as_f64().unwrap_or(0.0);
      let asset_type = if name.ends_with('!') {
        "OWNER"
      } else {
        "TOKEN"
      };
      items.push(AssetItem {
        name: name.to_string(),
        balance: format!("{:.8}", amount),
        asset_type: asset_type.to_string(),
      });
    }
  }
  Ok(items)
}

#[tauri::command]
fn transfer_asset(asset: String, amount: String, to: String) -> Result<String, String> {
  ensure_config()?;
  run_cli(&[String::from("transfer"), asset, amount, to])
}

#[tauri::command]
fn issue_asset(name: String, qty: String, units: u8, reissuable: bool) -> Result<String, String> {
  ensure_config()?;
  let qty_val: f64 = qty
    .trim()
    .parse()
    .map_err(|_| "Quantity must be a number".to_string())?;
  if units > 8 {
    return Err("Units must be between 0 and 8".to_string());
  }
  let flag = if reissuable { "true" } else { "false" };
  run_cli(&[
    String::from("issue"),
    name,
    format!("{qty_val}"),
    String::new(),
    String::new(),
    units.to_string(),
    flag.to_string(),
  ])
}

#[tauri::command]
fn wallet_encrypt(password: String) -> Result<String, String> {
  ensure_config()?;
  run_cli(&[String::from("encryptwallet"), password])
}

#[tauri::command]
fn wallet_unlock(password: String, duration: u64) -> Result<String, String> {
  ensure_config()?;
  run_cli(&[
    String::from("walletpassphrase"),
    password,
    duration.to_string(),
  ])
}

#[tauri::command]
fn wallet_lock() -> Result<String, String> {
  ensure_config()?;
  run_cli(&[String::from("walletlock")])
}

#[tauri::command]
fn run_cli_command(command: String, args: String) -> Result<String, String> {
  ensure_config()?;
  let mut full = Vec::new();
  if !command.trim().is_empty() {
    full.push(command.trim().to_string());
  }
  if !args.trim().is_empty() {
    full.extend(split_args(&args));
  }
  run_cli(&full)
}

#[tauri::command]
fn read_config() -> Result<String, String> {
  let cfg = ensure_config()?;
  fs::read_to_string(cfg).map_err(|e| e.to_string())
}

#[tauri::command]
fn write_config(contents: String) -> Result<(), String> {
  let cfg = ensure_config()?;
  fs::write(cfg, contents).map_err(|e| e.to_string())
}

#[tauri::command]
fn read_log(lines: Option<u32>) -> Result<String, String> {
  let dir = data_dir()?;
  let log_path = dir.join("debug.log");
  read_log_tail(&log_path, lines.unwrap_or(200) as usize)
}

#[tauri::command]
fn open_data_dir() -> Result<(), String> {
  let dir = data_dir()?;
  
  if cfg!(windows) {
    Command::new("explorer")
      .arg(&dir)
      .spawn()
      .map_err(|e| e.to_string())?;
      Ok(())
  } else if cfg!(target_os = "macos") {
    Command::new("open")
      .arg(&dir)
      .spawn()
      .map_err(|e| e.to_string())?;
      Ok(())
  } else {
    // Try dolphin directly (KDE)
    if Command::new("dolphin")
      .arg("--new-window")
      .arg(&dir)
      .spawn()
      .is_ok() {
      return Ok(());
    }
    
    // Try nautilus (GNOME)
    if Command::new("nautilus")
      .arg(&dir)
      .spawn()
      .is_ok()
    {
      return Ok(());
    }

    Ok(())
  }
}

#[tauri::command]
fn list_utxos() -> Result<Vec<UtxoItem>, String> {
  ensure_config()?;
  // listunspent 0 9999999 [] true
  let raw = run_cli(&[
    String::from("listunspent"),
    String::from("0"),
    String::from("9999999"),
    String::from("[]"),
    String::from("true"),
  ])?;
  let utxos: Vec<UtxoItem> = serde_json::from_str(&raw).map_err(|e| e.to_string())?;
  Ok(utxos)
}

#[derive(serde::Deserialize, serde::Serialize)]
struct RawTxInput {
  txid: String,
  vout: u64,
}

#[tauri::command]
fn broadcast_advanced_transaction(
  inputs: Vec<RawTxInput>,
  outputs: HashMap<String, String>, // Address -> AmountStr
) -> Result<String, String> {
  ensure_config()?;

  // 1. Create Raw Transaction
  // createrawtransaction [{"txid":"id","vout":n},...] {"address":amount,...}
  let inputs_json = serde_json::to_string(&inputs).map_err(|e| e.to_string())?;
  let outputs_json = serde_json::to_string(&outputs).map_err(|e| e.to_string())?;
  
  let raw_hex = run_cli(&[
    String::from("createrawtransaction"),
    inputs_json,
    outputs_json,
  ])?;

  // 2. Sign Raw Transaction
  // signrawtransaction <hex>
  let signed_res_raw = run_cli(&[
    String::from("signrawtransaction"),
    raw_hex,
  ])?;
  let signed_res: serde_json::Value = serde_json::from_str(&signed_res_raw).map_err(|e| e.to_string())?;
  
  let complete = signed_res["complete"].as_bool().unwrap_or(false);
  if !complete {
    return Err("Failed to sign transaction completely.".to_string());
  }
  let signed_hex = signed_res["hex"].as_str().ok_or("No signed hex returned")?.to_string();

  // 3. Send Raw Transaction
  let txid = run_cli(&[
    String::from("sendrawtransaction"),
    signed_hex,
  ])?;

  Ok(txid)
}


#[tauri::command]
fn backup_wallet() -> Result<String, String> {
  let dir = data_dir()?;
  let ts = Local::now().format("%Y%m%d_%H%M%S").to_string();
  let dest = dir.join(format!("hemp0x_backup_{}.dat", ts));
  let dest_str = dest.to_string_lossy().to_string();
  run_cli(&[String::from("backupwallet"), dest_str.clone()])?;
  Ok(dest_str)
}

#[tauri::command]
fn backup_wallet_to(path: String) -> Result<(), String> {
  run_cli(&[String::from("backupwallet"), path])?;
  Ok(())
}

fn wait_for_lock_release(dir: &Path) {
  let lock_path = dir.join(".lock");
  for _ in 0..20 {
    if !lock_path.exists() {
      break;
    }
    thread::sleep(Duration::from_millis(500));
  }
}

#[tauri::command]
fn restore_wallet(path: String, backup_existing: bool, restart_node: bool) -> Result<(), String> {
  let dir = data_dir()?;
    let wallet = dir.join("wallet.dat");
    if !Path::new(&path).exists() {
      return Err("Restore file not found.".to_string());
    }
    let _ = run_cli(&[String::from("stop")]);
    thread::sleep(Duration::from_secs(2));
    if wallet.exists() && backup_existing {
      let ts = Local::now().format("%Y%m%d_%H%M%S").to_string();
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
fn create_new_wallet(backup_existing: bool, restart_node: bool) -> Result<(), String> {
  let dir = data_dir()?;
    let wallet = dir.join("wallet.dat");
    let _ = run_cli(&[String::from("stop")]);
    thread::sleep(Duration::from_secs(2));
    if wallet.exists() && backup_existing {
      let ts = Local::now().format("%Y%m%d_%H%M%S").to_string();
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

#[tauri::command]
fn change_wallet_password(old_pass: String, new_pass: String) -> Result<String, String> {
  ensure_config()?;
  run_cli(&[
    String::from("walletpassphrasechange"),
    old_pass,
    new_pass,
  ])
}

// === DATA MANAGEMENT COMMANDS ===

#[derive(Serialize)]
struct DataFolderInfo {
  path: String,
  size_bytes: u64,
  size_display: String,
  config_exists: bool,
  wallet_exists: bool,
  folder_exists: bool,
}

fn calculate_dir_size(path: &Path) -> u64 {
  let mut total = 0u64;
  if let Ok(entries) = fs::read_dir(path) {
    for entry in entries.flatten() {
      let p = entry.path();
      if p.is_file() {
        total += fs::metadata(&p).map(|m| m.len()).unwrap_or(0);
      } else if p.is_dir() {
        total += calculate_dir_size(&p);
      }
    }
  }
  total
}

fn format_size(bytes: u64) -> String {
  const KB: u64 = 1024;
  const MB: u64 = KB * 1024;
  const GB: u64 = MB * 1024;
  
  if bytes >= GB {
    format!("{:.2} GB", bytes as f64 / GB as f64)
  } else if bytes >= MB {
    format!("{:.2} MB", bytes as f64 / MB as f64)
  } else if bytes >= KB {
    format!("{:.2} KB", bytes as f64 / KB as f64)
  } else {
    format!("{} bytes", bytes)
  }
}

#[tauri::command]
fn get_data_folder_info() -> Result<DataFolderInfo, String> {
  let dir = data_dir()?;
  let folder_exists = dir.exists();
  let config_exists = dir.join("hemp.conf").exists();
  let wallet_exists = dir.join("wallet.dat").exists();
  
  let size_bytes = if folder_exists { calculate_dir_size(&dir) } else { 0 };
  let size_display = format_size(size_bytes);
  
  Ok(DataFolderInfo {
    path: dir.to_string_lossy().to_string(),
    size_bytes,
    size_display,
    config_exists,
    wallet_exists,
    folder_exists,
  })
}

#[tauri::command]
fn check_config_exists() -> Result<bool, String> {
  let cfg = config_path()?;
  Ok(cfg.exists())
}

#[tauri::command]
fn backup_data_folder() -> Result<String, String> {
  let dir = data_dir()?;
  if !dir.exists() {
    return Err("Data folder does not exist".to_string());
  }
  
  let ts = Local::now().format("%Y%m%d_%H%M%S").to_string();
  let backup_name = format!("hemp0x_data_backup_{}", ts);
  
  let backup_base = dirs::desktop_dir()
    .or_else(dirs::home_dir)
    .ok_or("Could not determine backup location")?;
  let backup_path = backup_base.join(&backup_name);
  
  fn copy_dir_recursive(src: &Path, dst: &Path) -> Result<(), String> {
    fs::create_dir_all(dst).map_err(|e| e.to_string())?;
    for entry in fs::read_dir(src).map_err(|e| e.to_string())? {
      let entry = entry.map_err(|e| e.to_string())?;
      let src_path = entry.path();
      let dst_path = dst.join(entry.file_name());
      if src_path.is_dir() {
        copy_dir_recursive(&src_path, &dst_path)?;
      } else {
        fs::copy(&src_path, &dst_path).map_err(|e| e.to_string())?;
      }
    }
    Ok(())
  }
  
  copy_dir_recursive(&dir, &backup_path)?;
  Ok(backup_path.to_string_lossy().to_string())
}

#[tauri::command]
fn backup_data_folder_to(path: String) -> Result<(), String> {
  let dir = data_dir()?;
  if !dir.exists() {
    return Err("Data folder does not exist".to_string());
  }
  
  fn copy_dir_recursive(src: &Path, dst: &Path) -> Result<(), String> {
    fs::create_dir_all(dst).map_err(|e| e.to_string())?;
    for entry in fs::read_dir(src).map_err(|e| e.to_string())? {
      let entry = entry.map_err(|e| e.to_string())?;
      let src_path = entry.path();
      let dst_path = dst.join(entry.file_name());
      if src_path.is_dir() {
        copy_dir_recursive(&src_path, &dst_path)?;
      } else {
        fs::copy(&src_path, &dst_path).map_err(|e| e.to_string())?;
      }
    }
    Ok(())
  }
  
  copy_dir_recursive(&dir, Path::new(&path))?;
  Ok(())
}

#[tauri::command]
fn extract_binaries(target_dir: String) -> Result<String, String> {
  let target_path = PathBuf::from(target_dir);
  if !target_path.exists() {
    return Err("Target directory does not exist".to_string());
  }

  let bins = ["hemp0xd", "hemp0x-cli"];
  let mut extracted = Vec::new();

  for bin in bins {
    let src_str = resolve_bin(bin);
    let src = PathBuf::from(&src_str);
    if !src.exists() {
      // Try resolving without extension if on Windows and failed? No, resolve_bin handles it.
      return Err(format!("Source binary not found: {}", src_str));
    }

    let dest = target_path.join(bin_name(bin));
    fs::copy(&src, &dest).map_err(|e| format!("Failed to copy {}: {}", bin, e))?;

    // Set executable permissions on Linux/Mac
    #[cfg(unix)]
    {
       if let Ok(metadata) = fs::metadata(&dest) {
           let mut perms = metadata.permissions();
           perms.set_mode(0o755);
           let _ = fs::set_permissions(&dest, perms);
       }
    }
    extracted.push(bin);
  }

  Ok(format!("Successfully extracted: {}", extracted.join(", ")))
}


#[tauri::command]
fn create_default_config() -> Result<(), String> {
  let cfg = config_path()?;
  let dir = data_dir()?;
  
  if !dir.exists() {
    fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
  }
  
  let default_config = r#"# Hemp0x Configuration File
rpcuser=user
rpcpassword=password
server=1
daemon=0
listen=1
txindex=1
assetindex=1
"#;
  
  fs::write(&cfg, default_config).map_err(|e| e.to_string())?;
  Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
  tauri::Builder::default()
    .plugin(tauri_plugin_dialog::init())
    .plugin(tauri_plugin_shell::init())
    .setup(|app| {
      if cfg!(debug_assertions) {
        app.handle().plugin(
          tauri_plugin_log::Builder::default()
            .level(log::LevelFilter::Info)
            .build(),
        )?;
      }
      Ok(())
    })
    .invoke_handler(tauri::generate_handler![
      list_utxos,
      broadcast_advanced_transaction,
      init_config,
      dashboard_data,
      start_node,
      stop_node,
      get_receive_addresses,
      new_address,
      get_change_address,
      get_network_mode,
      set_network_mode,
      restart_app,
      send_hemp,
      list_assets,
      transfer_asset,
      issue_asset,
      wallet_encrypt,
        wallet_unlock,
        wallet_lock,
        run_shell_command,
        shell_autocomplete,
        run_cli_command,
      read_config,
      write_config,
      read_log,
      open_data_dir,
      backup_wallet,
      backup_wallet_to,
      restore_wallet,
      create_new_wallet,
      change_wallet_password,
      get_data_folder_info,
      check_config_exists,
      backup_data_folder,
      backup_data_folder_to,
      create_default_config,
      get_binary_status,
      extract_binaries
    ])
    .run(tauri::generate_context!())
    .expect("error while running tauri application");
}
