import express from 'express';
import { exec } from 'child_process';
import * as fs from 'fs';
import axios from 'axios';
import * as crypto from 'crypto';
const app = express();
const db: any = null;
app.get('/cmd', (req, res) => { exec('ping ' + req.query.h); });  // V:CMDI
app.get('/sql', (req, res) => { db.query("SELECT * FROM t WHERE n='" + req.query.n + "'"); });  // V:SQLI
app.get('/path', (req, res) => { res.send(fs.readFileSync('/data/' + req.query.f)); });  // V:PATH
app.get('/ssrf', (req, res) => { axios.get(req.query.u as string); });  // V:SSRF
app.get('/xss', (req, res) => { res.send('<h1>' + req.query.n + '</h1>'); });  // V:XSS
app.get('/eval', (req, res) => { eval(req.query.e as string); });  // V:EVAL
app.post('/deser', (req, res) => { const o = require('node-serialize').unserialize(req.body); });  // V:DESER
export const h = crypto.createHash('md5');  // V:CRYPTO
