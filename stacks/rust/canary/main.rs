use axum::{extract::Query, routing::get, Router};
use std::collections::HashMap;
use std::process::Command;
async fn cmd(Query(q): Query<HashMap<String, String>>) {
    Command::new("sh").arg("-c").arg(format!("ping {}", q["h"])).output().unwrap(); // V:CMDI
}
async fn sql(Query(q): Query<HashMap<String, String>>, pool: sqlx::PgPool) {
    sqlx::query(&format!("SELECT * FROM t WHERE n='{}'", q["n"])).execute(&pool).await.unwrap(); // V:SQLI
}
async fn path(Query(q): Query<HashMap<String, String>>) -> String {
    std::fs::read_to_string(format!("/data/{}", q["f"])).unwrap() // V:PATH
}
async fn ssrf(Query(q): Query<HashMap<String, String>>) -> String {
    reqwest::get(&q["u"]).await.unwrap().text().await.unwrap() // V:SSRF
}
fn weak(p: &str) -> md5::Digest {
    md5::compute(p) // V:CRYPTO
}
fn tls() -> reqwest::Client {
    reqwest::Client::builder().danger_accept_invalid_certs(true).build().unwrap() // V:TLS
}
