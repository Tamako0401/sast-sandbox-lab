# Third-party notices

本实验 rootfs 包含 Arch Linux `busybox 1.36.1-4` 软件包中的 x86_64
静态二进制。

- 项目：BusyBox
- 许可证：GPL-2.0-only
- 上游源码：`busybox-1.36.1.tar.bz2`
- 上游源码签名：`busybox-1.36.1.tar.bz2.sig`
- Arch 打包材料：`busybox-arch-packaging-1.36.1-4.tar.gz`
- Arch 打包标签：`1.36.1-4`，提交
  `6f31fcc720a1bbc869b9608e1dde18bc6a727b14`
- 本次二进制包 SHA-256：
  `14b14151bbc901c6e0c7cbb21fa73db2540df91cdea2a0ff1caf20be2cd8c333`
- 上游源码 SHA-256：
  `b8cc24c9574d809e7279c3be349795c5d5ceb6fdf19ca709f80cde50e47de314`
- Arch 打包材料 SHA-256：
  `335fa22452ab72ae50d1bf8ae3a65dae896e132fc6439470462628fc7abb1b02`

`2026.8-lab1` Release 同时提供二进制包、上游源码、签名、Arch 的
`PKGBUILD`、构建配置和补丁。源码签名已使用指纹
`C9E9416F76E610DBD09D040F47B70C55ACC9965B` 验证；完整文件哈希见
Release 中的 `SHA256SUMS`。

重新发布含 BusyBox 二进制的版本时，应继续在同一下载位置提供这些对应
源码材料，不要只复制二进制 rootfs。本文件不是法律意见；正式公开分发
前请再次核对 GPL-2.0-only 的源码提供义务。

