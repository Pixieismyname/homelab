import json
from mitmproxy import http

def response(flow: http.HTTPFlow):
    if 'tuya' not in flow.request.pretty_host:
        return
    try:
        data = json.loads(flow.response.text)
    except Exception:
        return

    keys = {}

    def search(obj):
        if isinstance(obj, dict):
            dev_id = obj.get('id') or obj.get('device_id') or obj.get('devId', '')
            local_key = obj.get('local_key') or obj.get('localKey', '')
            name = obj.get('name') or obj.get('custom_name', '')
            if dev_id and local_key:
                keys[dev_id] = {'name': name, 'local_key': local_key}
            for v in obj.values():
                search(v)
        elif isinstance(obj, list):
            for item in obj:
                search(item)

    search(data)

    if keys:
        with open('/home/mitmproxy/.mitmproxy/tuya_keys.json', 'w') as f:
            json.dump(keys, f, indent=2)
        for dev_id, info in keys.items():
            print(f'[KEY FOUND] {info["name"]} | id={dev_id} | local_key={info["local_key"]}', flush=True)
