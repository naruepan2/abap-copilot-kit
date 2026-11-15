// sap-auth-probe.js - ask the SAP system whether the stored credentials still work.
//
// Why Node and not PowerShell: this has to give the same answer ARC-1 will get. ARC-1 is Node, and
// on this machine PowerShell 5.1 refuses the TLS handshake to the SAP host entirely (Schannel),
// so a .NET probe would report "could not connect" for a perfectly good password.
//
// One request, the cheapest one that proves authentication: ADT discovery with Basic auth.
//
// Output, one line, always the same shape:
//   OK <status>       the credentials work
//   STALE <status>    the system rejected them (401) - the password changed or expired
//   UNKNOWN <reason>  no conclusion: network, TLS, server down, unexpected status
//
// Exit codes: 0 OK, 1 STALE, 2 UNKNOWN. A caller must treat UNKNOWN as "carry on", never as a
// reason to ask the user for a new password.
//
// Environment in: ARC1_PROBE_URL (full discovery URL, with sap-client), ARC1_PROBE_USER,
// ARC1_PROBE_PASS. NODE_EXTRA_CA_CERTS is honoured by Node itself.
'use strict';

const https = require('https');

const url = process.env.ARC1_PROBE_URL;
const user = process.env.ARC1_PROBE_USER;
const pass = process.env.ARC1_PROBE_PASS;

function done(line, code) {
    process.stdout.write(line + '\n');
    process.exit(code);
}

if (!url || !user || typeof pass !== 'string') {
    done('UNKNOWN missing ARC1_PROBE_URL, ARC1_PROBE_USER or ARC1_PROBE_PASS', 2);
}

let target;
try {
    target = new URL(url);
} catch (e) {
    done('UNKNOWN invalid ARC1_PROBE_URL', 2);
}
if (target.protocol !== 'https:' && target.protocol !== 'http:') {
    done('UNKNOWN ARC1_PROBE_URL must be http or https', 2);
}

// The module has to match the URL. Asking https.request for an http: URL throws
// ERR_INVALID_PROTOCOL synchronously, outside any callback - and because the process then dies
// with exit code 1, a crash looked exactly like the documented STALE verdict. The launcher would
// have asked for a new password when the only thing wrong was the scheme.
const transport = target.protocol === 'http:' ? require('http') : require('https');

const auth = 'Basic ' + Buffer.from(user + ':' + pass, 'utf8').toString('base64');

let req;
try {
    req = transport.request(
        {
            hostname: target.hostname,
            port: target.port,
            path: target.pathname + target.search,
            method: 'GET',
            timeout: 15000,
            headers: {
                authorization: auth,
                accept: 'application/atomsvc+xml',
                'x-csrf-token': 'fetch',
                'sap-client': process.env.ARC1_PROBE_CLIENT || '',
                'user-agent': 'arc1-auth-probe'
            }
        },
        (res) => {
            // Drain the body so the socket can close; we only care about the status.
            res.resume();
            res.on('end', () => {
                const s = res.statusCode;
                if (s >= 200 && s < 300) done('OK ' + s, 0);
                if (s === 401) done('STALE ' + s, 1);
                done('UNKNOWN ' + s, 2);
            });
        }
    );
} catch (e) {
    done('UNKNOWN ' + (e.code || e.message), 2);
}

req.on('timeout', () => {
    req.destroy();
    done('UNKNOWN timeout', 2);
});
req.on('error', (e) => {
    done('UNKNOWN ' + (e.code || e.message), 2);
});
req.end();
