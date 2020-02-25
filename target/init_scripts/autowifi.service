[Unit]
Description==booting wifi ...
After=wpa_supplicant.service network.target local-fs.target udhcpd.service 
Before=sshd.service

[Service]
Type=forking
ExecStart=/bin/bash /opt/scripts/boot/autowifi.sh

[Install]
WantedBy=multi-user.target