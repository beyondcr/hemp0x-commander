
#[tauri::command]
fn encrypt_new_wallet(password: String) -> Result<String, String> {
  ensure_config()?;
  // encryptwallet <passphrase>
  run_cli(&[
    String::from("encryptwallet"),
    password,
  ])
}
