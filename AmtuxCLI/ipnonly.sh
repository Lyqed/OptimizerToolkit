echo Local IP Config: && ip -4 addr | grep -oP "(?<=inet\s)\d+(\.\d+){3}" && echo Public IP: && curl -s http://checkip.amazonaws.com
