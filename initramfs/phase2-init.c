typedef unsigned int size_t;

#define O_RDONLY 0
#define O_WRONLY 1
#define O_RDWR 2

static long sys_call0(long n)
{
    register long r7 __asm__("r7") = n;
    register long r0 __asm__("r0");
    __asm__ volatile("svc #0" : "=r"(r0) : "r"(r7) : "memory");
    return r0;
}

static long sys_call1(long n, long a0)
{
    register long r7 __asm__("r7") = n;
    register long r0 __asm__("r0") = a0;
    __asm__ volatile("svc #0" : "+r"(r0) : "r"(r7) : "memory");
    return r0;
}

static long sys_call2(long n, long a0, long a1)
{
    register long r7 __asm__("r7") = n;
    register long r0 __asm__("r0") = a0;
    register long r1 __asm__("r1") = a1;
    __asm__ volatile("svc #0" : "+r"(r0) : "r"(r1), "r"(r7) : "memory");
    return r0;
}

static long sys_call3(long n, long a0, long a1, long a2)
{
    register long r7 __asm__("r7") = n;
    register long r0 __asm__("r0") = a0;
    register long r1 __asm__("r1") = a1;
    register long r2 __asm__("r2") = a2;
    __asm__ volatile("svc #0" : "+r"(r0) : "r"(r1), "r"(r2), "r"(r7) : "memory");
    return r0;
}

static long sys_call4(long n, long a0, long a1, long a2, long a3)
{
    register long r7 __asm__("r7") = n;
    register long r0 __asm__("r0") = a0;
    register long r1 __asm__("r1") = a1;
    register long r2 __asm__("r2") = a2;
    register long r3 __asm__("r3") = a3;
    __asm__ volatile("svc #0" : "+r"(r0) : "r"(r1), "r"(r2), "r"(r3), "r"(r7) : "memory");
    return r0;
}

static long sys_call5(long n, long a0, long a1, long a2, long a3, long a4)
{
    register long r7 __asm__("r7") = n;
    register long r0 __asm__("r0") = a0;
    register long r1 __asm__("r1") = a1;
    register long r2 __asm__("r2") = a2;
    register long r3 __asm__("r3") = a3;
    register long r4 __asm__("r4") = a4;
    __asm__ volatile(
        "svc #0"
        : "+r"(r0)
        : "r"(r1), "r"(r2), "r"(r3), "r"(r4), "r"(r7)
        : "memory");
    return r0;
}

static long sys_read(long fd, void *buf, size_t len) { return sys_call3(3, fd, (long)buf, len); }
static long sys_write(long fd, const void *buf, size_t len) { return sys_call3(4, fd, (long)buf, len); }
static long sys_open(const char *path, long flags, long mode) { return sys_call3(5, (long)path, flags, mode); }
static long sys_close(long fd) { return sys_call1(6, fd); }
static long sys_mkdir(const char *path, long mode) { return sys_call2(39, (long)path, mode); }
static long sys_mount(const char *src, const char *target, const char *type, long flags, const void *data)
{
    return sys_call5(21, (long)src, (long)target, (long)type, flags, (long)data);
}
static long sys_reboot(void) { return sys_call4(88, 0xfee1dead, 0x28121969, 0x01234567, 0); }

static unsigned int fb_buffer[1024];
static char line[160];
static char file_buffer[512];

static size_t str_len(const char *s)
{
    size_t len = 0;
    while (s[len])
        len++;
    return len;
}

static int str_eq(const char *a, const char *b)
{
    while (*a && *b && *a == *b) {
        a++;
        b++;
    }
    return *a == 0 && *b == 0;
}

static int starts_with(const char *s, const char *prefix)
{
    while (*prefix) {
        if (*s++ != *prefix++)
            return 0;
    }
    return 1;
}

static void write_all(long fd, const char *s)
{
    size_t off = 0;
    size_t len = str_len(s);
    while (off < len) {
        long wrote = sys_write(fd, s + off, len - off);
        if (wrote <= 0)
            return;
        off += (size_t)wrote;
    }
}

static void mount_basic_fs(void)
{
    sys_mkdir("/proc", 0555);
    sys_mkdir("/sys", 0555);
    sys_mkdir("/tmp", 0777);
    sys_mount("proc", "/proc", "proc", 0, 0);
    sys_mount("sysfs", "/sys", "sysfs", 0, 0);
}

static long open_framebuffer(void)
{
    long fd = sys_open("/dev/fb0", O_WRONLY, 0);
    if (fd >= 0)
        return fd;
    return sys_open("/dev/graphics/fb0", O_WRONLY, 0);
}

static void paint_framebuffer(long out)
{
    long fd = open_framebuffer();
    int i;
    int blocks;

    if (fd < 0) {
        write_all(out, "framebuffer: open failed\n");
        return;
    }

    for (i = 0; i < 1024; i++) {
        if (i & 1)
            fb_buffer[i] = 0x001f001f;
        else
            fb_buffer[i] = 0x07e007e0;
    }

    for (blocks = 0; blocks < 225; blocks++) {
        long wrote = sys_write(fd, fb_buffer, sizeof(fb_buffer));
        if (wrote <= 0) {
            write_all(out, "framebuffer: write failed\n");
            sys_close(fd);
            return;
        }
    }

    sys_close(fd);
    write_all(out, "framebuffer: painted green/blue diagnostic pattern\n");
}

static void print_file(long out, const char *path)
{
    long fd = sys_open(path, O_RDONLY, 0);
    if (fd < 0) {
        write_all(out, "cat: open failed: ");
        write_all(out, path);
        write_all(out, "\n");
        return;
    }

    for (;;) {
        long n = sys_read(fd, file_buffer, sizeof(file_buffer));
        if (n <= 0)
            break;
        sys_write(out, file_buffer, (size_t)n);
    }
    sys_close(fd);
    write_all(out, "\n");
}

static int read_line(long fd, long out)
{
    int pos = 0;
    for (;;) {
        char ch = 0;
        long n = sys_read(fd, &ch, 1);
        if (n <= 0)
            return 0;
        if (ch == '\r' || ch == '\n') {
            line[pos] = 0;
            write_all(out, "\n");
            return 1;
        }
        if ((ch == 8 || ch == 127) && pos > 0) {
            pos--;
            write_all(out, "\b \b");
            continue;
        }
        if (pos < (int)sizeof(line) - 1) {
            line[pos++] = ch;
            sys_write(out, &ch, 1);
        }
    }
}

static void print_help(long out)
{
    write_all(out, "Commands: help status fb cat jp reboot\n");
    write_all(out, "  status             show mounted pseudo-fs and useful probes\n");
    write_all(out, "  fb                 repaint framebuffer diagnostic pattern\n");
    write_all(out, "  cat /proc/cmdline  print a kernel/proc/sys file\n");
    write_all(out, "  jp                 print UTF-8 Japanese display probe text\n");
    write_all(out, "  reboot             reboot through the kernel syscall\n");
}

static void print_status(long out)
{
    write_all(out, "is01 phase2 userspace status\n");
    write_all(out, "rootfs: initramfs raw newc cpio\n");
    write_all(out, "boot image: stock recovery kernel, 4096-byte section alignment\n");
    print_file(out, "/proc/cmdline");
}

static void run_command(long out)
{
    if (str_eq(line, "") || str_eq(line, "help")) {
        print_help(out);
    } else if (str_eq(line, "status")) {
        print_status(out);
    } else if (str_eq(line, "fb")) {
        paint_framebuffer(out);
    } else if (str_eq(line, "jp")) {
        write_all(out, "日本語 UTF-8 display probe: あいうえお IS01\n");
    } else if (str_eq(line, "reboot")) {
        write_all(out, "rebooting now\n");
        sys_reboot();
        write_all(out, "reboot syscall failed\n");
    } else if (starts_with(line, "cat /")) {
        print_file(out, line + 4);
    } else {
        write_all(out, "unknown command: ");
        write_all(out, line);
        write_all(out, "\n");
        print_help(out);
    }
}

void _start(void)
{
    long console = sys_open("/dev/console", O_RDWR, 0);
    long out = console >= 0 ? console : 1;

    mount_basic_fs();
    write_all(out, "\n");
    write_all(out, "is01 phase2 userspace: interactive initramfs shell\n");
    print_help(out);
    paint_framebuffer(out);

    for (;;) {
        write_all(out, "phase2# ");
        if (!read_line(out, out))
            write_all(out, "console read failed; waiting\n");
        else
            run_command(out);
    }
}
