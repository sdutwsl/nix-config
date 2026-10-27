# AIC8800DC / FC (UGREEN CM760-35262)

Tested on Linux kernel 6.16 with openSUSE Tumbleweed.

src: https://www.lulian.cn/download/122.html (UGREEN CM760-35262, `a69c:88de`)

## Disclaimer

I did not develop this software, The code is sourced from the UGREEN CM760-35262 driver. I only made some modifications to the code to adapt it to newer kernel versions. Apart from compilation issues, I am unable to address other problems. Some modifications are adapted from [shenmintao/aic8800d80](https://github.com/shenmintao/aic8800d80). Credit to the original authors.

# Usage

```bash
# sometimes you will need to eject the driver disk to switch working mode
# the aic.rules should handle this (eject a69c:5721 and a69c:5722)
# install setup files, scripts from UGREEN
chmod +x install_setup.sh
sudo ./install_setup.sh

# build kernel module
cd drivers/aic8800
make
sudo make install

# load kernel modules
sudo modprobe aic8800_fdrv
sudo modprobe aic_load_fw
```