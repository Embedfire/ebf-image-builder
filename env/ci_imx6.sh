

echo '' |  make uboot  DOWNLOAD_MIRROR=china   \
                      FIRE_BOARD=ebf_imx_6ull_pro  \
                      LINUX=4.19.35  \
                      UBOOT=2020.10 \
                      DISTRIBUTION=Debian \
                      DISTRIB_RELEASE=buster \
                      DISTRIB_TYPE=console \
                      INSTALL_TYPE=ALL  \
