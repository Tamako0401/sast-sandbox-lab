# SAST Sandbox Lab

这是第三题的出题组材料。它只提供可运行的最小 rootfs、待补全的
`sandbox-run` 脚手架和一个合并后的验收任务 `job.sh`，不提供完整
Runner。

## 文件说明

```text
sast-sandbox-lab/
├── rootfs.tar.zst
├── rootfs.tar.zst.sha256
├── build-rootfs.sh
├── sandbox-run.sh.template
├── job.sh
├── rootfs-overlay/
└── THIRD_PARTY_NOTICES.md
```

`rootfs.tar.zst` 面向 `x86_64/amd64`，核心是静态链接的 BusyBox，解压后
约 2 MiB。它包含 `/bin/sh`、`hostname`、`ps`、`mount`、`cat`、`echo`
以及测试脚本所需的少量命令；预先创建了 `/dev`、`/proc`、`/tmp` 和
`/workspace`。它不包含包管理器、编译器、网络客户端或 systemd。

rootfs 不携带设备节点。运行盒子应在自己的 mount namespace 中只把宿主
`/dev/null` 绑定到 `rootfs/dev/null`；不要为了省事绑定整个 `/dev`。

## 出题组构建与检查

在 x86_64 Linux 上安装 `bash`、`curl`、GNU `tar`、`zstd`、
`coreutils`、`file` 后执行：

```bash
./build-rootfs.sh
sha256sum -c rootfs.tar.zst.sha256
sudo ./verify-rootfs.sh
```

构建脚本固定 BusyBox 版本和 SHA-256。默认下载镜像失效时，可以只替换
下载地址，内容哈希不匹配仍会终止构建：

```bash
BUSYBOX_PACKAGE_URL='https://example.invalid/busybox.pkg.tar.zst' \
  ./build-rootfs.sh
```

## 学生使用方式

学生不需要构建 rootfs。发给学生的压缩包中已经包含
`rootfs.tar.zst`：

```bash
mkdir rootfs
sudo tar --zstd -xpf rootfs.tar.zst -C rootfs
cp sandbox-run.sh.template sandbox-run
chmod +x sandbox-run
```

学生在第二题修好的 Gitea 中创建自己的仓库，加入出题组提供的
`job.sh`，再手动克隆到第一题的 Ubuntu 24.04 环境。克隆必须发生在
隔离环境外，预期调用关系是：

```text
Gitea 仓库 -> 手动 git clone -> 本地工作目录 -> sandbox-run -> job.sh
```

最终接口建议统一为：

```bash
sudo ./sandbox-run ./job.sh
```

`job.sh` 会依次检查题面的五项预期：

1. UTS namespace 独立，且只在确认独立后测试盒内 hostname 修改；
2. PID namespace 独立，`/proc/1` 属于盒内 PID namespace；
3. mount namespace 独立，`/proc` 是盒内单独挂载的 proc 文件系统；
4. `/etc/sast-rootfs-release` 能确认正在使用出题组的最小 rootfs；
5. 预先克隆的 `job.sh` 从 `/workspace` 暴露给盒内，盒内无需提供 Git。

单项检查失败不会让后续检查中断。所有检查执行完毕后，脚本统一输出
`overall: COMPLETE` 或 `overall: INCOMPLETE`；未完成时最终退出码为 1。

为了让 `job.sh` 能安全、准确地比较 namespace，学生的 `sandbox-run`
应在调用 `unshare` 前读取宿主机的 namespace 标识，并将它们分别通过
`SAST_HOST_UTS_NS`、`SAST_HOST_PID_NS`、`SAST_HOST_MNT_NS` 传入盒内。
例如宿主标识可由以下命令取得：

```bash
readlink /proc/self/ns/uts
readlink /proc/self/ns/pid
readlink /proc/self/ns/mnt
```

若缺少这些基准值，`job.sh` 会把对应项目记为失败但继续完成其余检查。
这样即使 Runner 尚未正确创建 UTS namespace，验收脚本也不会贸然修改
宿主机 hostname。

## 分发建议

源仓库只维护构建脚本、overlay、题目脚手架、测试任务和说明，不把生成的
二进制归档直接提交进 Git。每次定稿打一个版本标签，例如
`2026.8-lab1`，把以下文件作为同一个 Release 的附件：

- `rootfs.tar.zst` 及对应的 `.sha256`；
- 构建 rootfs 所用的原始 BusyBox 二进制包及签名；
- BusyBox 对应源码、签名和 Arch 打包材料，见
  `THIRD_PARTY_NOTICES.md`。

不要要求学生用自己刚修好的 Gitea 下载出题附件；试题平台或群文件仍应
提供一份 Release 压缩包。Gitea 仓库只负责第三题中的手动克隆流程和
`job.sh` 版本记录。
