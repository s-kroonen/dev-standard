// CANARY: planted vulnerabilities for scripts/check canary. Never built, never imported.
import { Controller, Get, Post, Query, Body, Res } from '@nestjs/common';
import { exec } from 'child_process';
import * as fs from 'fs';
import axios from 'axios';

const ALLOWED_HOSTS = ['example.com'];

@Controller('canary')
export class CanaryController {
  constructor(private readonly model: any) {}

  @Get('exec') a(@Query('host') host: string) { exec('ping -c 1 ' + host); }
  @Post('eval') b(@Body() body: any) { return eval(body.expr); }
  @Get('nosql') c(@Query('q') q: string) { return this.model.find({ $where: q }); }
  @Get('xss') d(@Query('name') name: string, @Res() res: any) { res.send('<h1>' + name + '</h1>'); }
  @Get('path') e(@Query('f') f: string) { return fs.readFileSync('/data/' + f); }
  @Get('ssrf') f(@Query('url') url: string) {
    const parsed = new URL(url);
    if (!ALLOWED_HOSTS.some((h) => parsed.hostname.endsWith(h))) throw new Error('not allowed');
    return axios.get(url);
  }
}
