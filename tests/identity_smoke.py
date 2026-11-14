#!/usr/bin/env python3
"""Check HTTP and JavaScript identity against a local loopback server."""
import html.parser
import http.server
import json
import subprocess
import sys
import threading
from pathlib import Path


class Page(http.server.BaseHTTPRequestHandler):
    requests = []

    def do_GET(self):
        type(self).requests.append(dict(self.headers.items()))
        body = b'''<!doctype html><html><body><script>
        document.body.setAttribute('data-ua', navigator.userAgent);
        document.body.setAttribute('data-version', navigator.appVersion);
        document.body.setAttribute('data-vendor', navigator.vendor);
        document.body.setAttribute('data-brands', JSON.stringify(navigator.userAgentData.brands));
        </script></body></html>'''
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        pass


class Body(html.parser.HTMLParser):
    attrs = None

    def handle_starttag(self, tag, attrs):
        if tag == 'body':
            self.attrs = dict(attrs)


def check(binary, url, options, mode):
    before = len(Page.requests)
    result = subprocess.run(
        [binary, 'fetch', '--dump', 'html', '--wait-ms', '250', *options, url],
        capture_output=True, text=True, timeout=45, check=True,
    )
    assert len(Page.requests) > before, (mode, result.stderr)
    headers = {key.lower(): value for key, value in Page.requests[before].items()}
    page = Body()
    page.feed(result.stdout)
    attrs = page.attrs
    assert attrs is not None and 'data-ua' in attrs, (mode, result.stdout, result.stderr)
    assert attrs['data-ua'] == headers['user-agent'], (mode, attrs, headers)
    brands = json.loads(attrs['data-brands'])
    if mode == 'chrome':
        assert 'Chrome/149.0.0.0' in attrs['data-ua'], attrs
        assert attrs['data-version'] == attrs['data-ua'].removeprefix('Mozilla/'), attrs
        assert attrs['data-vendor'] == 'Google Inc.', attrs
        assert brands[0] == {'brand': 'Google Chrome', 'version': '149'}, brands
        assert '"Chromium";v="149"' in headers['sec-ch-ua'], headers
        assert headers['sec-ch-ua-mobile'] == '?0', headers
        assert headers['sec-ch-ua-platform'] == '"Linux"', headers
        assert 'sec-ch-ua-full-version-list' not in headers, headers
    elif mode == 'legacy':
        assert attrs['data-ua'] == 'Lightpanda/1.0', attrs
        assert attrs['data-vendor'] == '', attrs
        assert brands == [{'brand': 'Lightpanda', 'version': '1'}], brands
        assert headers['sec-ch-ua'] == '"Lightpanda";v="1"', headers
        assert 'sec-ch-ua-full-version-list' in headers, headers
        assert 'sec-ch-ua-mobile' not in headers and 'sec-ch-ua-platform' not in headers, headers
    else:
        assert attrs['data-ua'] == 'CustomBrowser/7.0', attrs
        assert brands == [], brands
        assert 'sec-ch-ua' not in headers, headers
        assert 'sec-ch-ua-mobile' not in headers and 'sec-ch-ua-platform' not in headers, headers


def main():
    binary = str(Path(sys.argv[1]).resolve())
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Page)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    url = f'http://127.0.0.1:{server.server_port}/'
    try:
        check(binary, url, [], 'chrome')
        check(binary, url, ['--disable-chrome-identity'], 'legacy')
        check(binary, url, ['--user-agent', 'CustomBrowser/7.0'], 'custom')
    finally:
        server.shutdown()
        server.server_close()
        thread.join()
    print('Identity smoke tests passed')


if __name__ == '__main__':
    main()
