# ebf-image-builder

配置信息存放于三个不同文件,可用于深度配置系统镜像特性：
- configs/common.conf：开发板公共配置，用于配置文件系统、生成文件路径等
- configs/boards/xxx.conf：开发板特殊配置，用于配置uboot、kernel、设备树插件等

- configs/user.conf：用户信息配置，用于系统配置登录欢迎语、用户名、密码等