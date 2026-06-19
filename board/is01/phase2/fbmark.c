#include <errno.h>
#include <fcntl.h>
#include <linux/fb.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

static int open_fb(void)
{
	int fd = open("/dev/graphics/fb0", O_RDWR);
	if (fd >= 0)
		return fd;
	return open("/dev/fb0", O_RDWR);
}

static void console_note(const char *message)
{
	const char *paths[] = { "/dev/console", "/dev/tty1", NULL };
	int i;

	for (i = 0; paths[i]; i++) {
		int fd = open(paths[i], O_WRONLY | O_NOCTTY);
		if (fd < 0)
			continue;
		write(fd, message, strlen(message));
		close(fd);
	}
}

int main(void)
{
	struct fb_var_screeninfo var;
	struct fb_fix_screeninfo fix;
	unsigned int x;
	unsigned int y;
	unsigned int width = 960;
	unsigned int height = 480;
	unsigned int line_length = 960 * 2;
	int fd;

	console_note("\nIS01 Phase 2 Buildroot boot probe reached\n");

	fd = open_fb();
	if (fd < 0) {
		perror("open framebuffer");
		return 1;
	}

	memset(&var, 0, sizeof(var));
	memset(&fix, 0, sizeof(fix));
	if (ioctl(fd, FBIOGET_VSCREENINFO, &var) == 0 && var.xres > 0 && var.yres > 0) {
		width = var.xres;
		height = var.yres;
	}
	if (ioctl(fd, FBIOGET_FSCREENINFO, &fix) == 0 && fix.line_length > 0)
		line_length = fix.line_length;

	for (y = 0; y < height; y++) {
		for (x = 0; x < width; x++) {
			uint16_t color;
			off_t offset = (off_t)y * line_length + (off_t)x * 2;

			if (y < height / 6)
				color = 0xf800;
			else if (y < (height * 2) / 6)
				color = 0x07e0;
			else if (y < (height * 3) / 6)
				color = 0x001f;
			else if (y < (height * 4) / 6)
				color = 0xffe0;
			else if (y < (height * 5) / 6)
				color = 0xf81f;
			else
				color = 0xffff;

			if (pwrite(fd, &color, sizeof(color), offset) != sizeof(color)) {
				perror("write framebuffer");
				close(fd);
				return 1;
			}
		}
	}

	fsync(fd);
	close(fd);
	console_note("IS01 Phase 2 framebuffer marker drawn; reboot probe armed\n");
	return 0;
}
