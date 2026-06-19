typedef unsigned int size_t;

#define O_RDWR 2

struct timespec {
    long tv_sec;
    long tv_nsec;
};

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

static long sys_write(long fd, const void *buf, size_t len) { return sys_call3(4, fd, (long)buf, len); }
static long sys_open(const char *path, long flags, long mode) { return sys_call3(5, (long)path, flags, mode); }
static long sys_nanosleep(const struct timespec *req, struct timespec *rem)
{
    return sys_call2(162, (long)req, (long)rem);
}
static long sys_reboot(void) { return sys_call4(88, 0xfee1dead, 0x28121969, 0x01234567, 0); }

static size_t str_len(const char *s)
{
    size_t len = 0;
    while (s[len])
        len++;
    return len;
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

static void sleep_seconds(long seconds)
{
    struct timespec req;
    req.tv_sec = seconds;
    req.tv_nsec = 0;
    sys_nanosleep(&req, 0);
}

void _start(void)
{
    long console = sys_open("/dev/console", O_RDWR, 0);
    long out = console >= 0 ? console : 1;

    write_all(out, "\n");
    write_all(out, "is01 phase3 mainline minimal init: reached userspace\n");
    write_all(out, "is01 phase3 mainline minimal init: rebooting in 20 seconds\n");
    sleep_seconds(20);
    write_all(out, "is01 phase3 mainline minimal init: reboot now\n");
    sys_reboot();

    for (;;)
        sleep_seconds(60);
}
