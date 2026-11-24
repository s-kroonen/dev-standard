using System.Diagnostics;
using System.Data.SqlClient;
using Microsoft.AspNetCore.Mvc;
using System.Security.Cryptography;
using System.Runtime.Serialization.Formatters.Binary;
[ApiController]
public class C : ControllerBase {
    SqlConnection conn;
    [HttpGet("cmd")] public void Cmd(string h) { Process.Start("cmd.exe", "/c ping " + h); } // V:CMDI
    [HttpGet("sql")] public void Sql(string n) { new SqlCommand("SELECT * FROM t WHERE n='" + n + "'", conn).ExecuteReader(); } // V:SQLI
    [HttpGet("path")] public string Path(string f) { return System.IO.File.ReadAllText("/data/" + f); } // V:PATH
    [HttpGet("ssrf")] public string Ssrf(string u) { return new System.Net.Http.HttpClient().GetStringAsync(u).Result; } // V:SSRF
    [HttpPost("deser")] public object Deser() { return new BinaryFormatter().Deserialize(Request.Body); } // V:DESER
    [HttpGet("xss")] public ContentResult Xss(string n) { return Content("<h1>" + n + "</h1>", "text/html"); } // V:XSS
    public byte[] Weak(byte[] d) { return MD5.Create().ComputeHash(d); } // V:CRYPTO
}
