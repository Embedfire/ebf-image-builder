# ebf-image-builder
 
## Ubuntu/Debian镜像构建工具

- 适用对象：野火linux imx8mm开发板
- 运行环境：Ubuntu 20.04

你可以使用ebf-image-builder脚本来编译Ubuntu/Debian固件。

## 如何使用

### 1.安装基本软件包

```
$ sudo apt-get update
$ sudo apt install make gcc-arm-linux-gnueabihf gcc-aarch64-linux-gnu device-tree-compiler gcc bison flex libssl-dev dpkg-dev lzop

```
### 2.克隆ebf-image-builder仓库

```
$ mkdir -p ~/project/embedfire
$ cd ~/project/embedfire
$ git clone --depth 1  xxx 
$ cd ebf-image-builder
```

### 3.设置编译环境

```
$ source env/setenv.sh
```

你需要先设置ebf-image-builder编译环境，如：选择安装方式、linux开发板型号、u-boot版本、linux版本、文件系统类型等等。

**注意**：每个选项的后面通过类似"[x]"的标志来表明默认选中第x项。
具体说明如下：

#### 选择安装方式（默认）

```
$ Choose install type:
  1.xxx
```
只有编译imx6镜像时才会针对不同flash介质，需要使用不同版本uboot：
- eMMC/SD:uboot从eMMC/SD加载并启动linux系统
- nandflsh:uboot从nandflsh加载并启动linux系统
- ALL:编译所有版本的uboot，以实现一个镜像适用所有介质

**编译系统镜像时，请选择安装介质类型为"ALL"。**

单独编译uboot则可以选择其他安装介质类型

#### 选择开发板型号

```
$ Choose fire board:
  1.xxx
  ...
```
野火将提供多款不同linux开发版，请根据自己的开发板类型进行选择。

#### 选择uboot版本

```
$ Choose uboot version:
  1.xxx
  ...
```
野火维护多种不同版本uboot，如无特殊需求，请使用默认选项。

#### 选择linux版本

```
$ Choose linux version:
  1.xxx
  ...
```
野火维护多种不同版本linux内核，如无特殊需求，请使用默认选项。

#### 选择发行版系统

```
$ Choose distribution:
  1.xxx
  ...
```
主要支持debian/ubuntu文件系统，请根据实际需求选择。

#### 选择系统版本

```
$ Choose xxx release:
  1.xxx
  ...
```
发行版系统有多种版本，请根据实际需求选择。

#### 选择镜像版本

```
$ Choose xxx type:
  1.xxx
  ...
```
生成镜像有多种版本：
- console：纯净版镜像，没有带桌面环境和野火的QT App。

- qt：具有完整QT App功能的镜像,系统启动后会进入QT App的界面。

- xfce：xfce桌面环境的镜像，系统启动后会进入桌面环境。

请根据实际需求选择不同版本镜像。

[更多配置信息](doc/setting.md)

### 4.开始编译完整固件

```
$ make
```
**编译选项**：
- DOWNLOAD_MIRROR：如果是国内用户，可加入**DOWNLOAD_MIRROR=china**选项，以提高文件下载速度。
- FORCE_UPDATE：当重复多次编译镜像时，uboot、内核并不会反复编译。如果需要重新编译uboot、内核，可加入**FORCE_UPDATE=enable**选项。
- SOURCE_URL: 内部单独编译测试使用命令**make SOURCE_URL=gitlab DOWNLOAD_MIRROR=china**，提高文件下载速度。

在设置好环境执行make就会开始编译，如果编译过程会用到root权限，将提示你要输入密码才能继续编译。

```
$ Building rootfs stage requires root privileges, please enter your passowrd:
```

**编译成功后，image镜像位于deploy/xxx目录下**。



## 单独编译

**当然，你也可以选择单独编译u-boot和内核。**

### 编译U-boot

```
$ make uboot
```

### 编译内核

```
$ make kernel
```
**编译成功后，生成文件位于build/images目录下**。

### 编译内核安装包

```
$ make kernel-deb
```
**编译成功后，生成deb包位于build/debs目录下**。

**提示**：在镜像的第一次编译过程中，所需时间会比较久，因为脚本会检测你的电脑的编译环境，安装编译需要的一些软件包，同时还会从野火官方仓库下载一些构建镜像所需的内容。

### 参考资料：
#### BeagleBone

Checkout this [documents](https://github.com/beagleboard/image-builder/blob/master/readme.md)

#### fenix
Checkout this [documents](https://github.com/khadas/fenix/README.md)
 
