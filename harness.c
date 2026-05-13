#include <sixel.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>

#define CONTROL_SIZE 8
#define GIF_HEADER_SIZE 6
#define TRUEVISION_MIN_GIF_SIZE 18

static void
set_option(sixel_encoder_t *encoder, int option, const char *value)
{
    (void)sixel_encoder_setopt(encoder, option, value);
}

static void
set_flag(sixel_encoder_t *encoder, int option)
{
    (void)sixel_encoder_setopt(encoder, option, "");
}

/*
 * Optimized Persistent Mode Harness for libsixel
 */

int main(int argc, char *argv[]) {
    // We will save the incoming bytes (after the control bytes) to a temp file
    char filename[256];
    int allow_nongif = getenv("SIXEL_HARNESS_ALLOW_NONGIF") != NULL;
    int truevision_patch = getenv("TRUEVISION_PATCH") != NULL;
    snprintf(filename, sizeof(filename), "/dev/shm/fuzz_input_%d.gif", getpid());

    while (__AFL_LOOP(1000)) {
        // Rewind stdin, as afl-fuzz will feed the testcase here.
        lseek(STDIN_FILENO, 0, SEEK_SET);

        unsigned char control[CONTROL_SIZE];
        ssize_t n = read(STDIN_FILENO, control, sizeof(control));
        if (n != (ssize_t)sizeof(control)) {
            continue;
        }

        unsigned char gif_header[GIF_HEADER_SIZE];
        n = read(STDIN_FILENO, gif_header, sizeof(gif_header));
        if (n != (ssize_t)sizeof(gif_header)) {
            continue;
        }
        if (!allow_nongif &&
            memcmp(gif_header, "GIF87a", sizeof(gif_header)) != 0 &&
            memcmp(gif_header, "GIF89a", sizeof(gif_header)) != 0) {
            continue;
        }

        int fd = open(filename, O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (fd < 0) {
            continue;
        }

        write(fd, gif_header, sizeof(gif_header));
        size_t gif_size = sizeof(gif_header);

        char buf[4096];
        while ((n = read(STDIN_FILENO, buf, sizeof(buf))) > 0) {
            write(fd, buf, n);
            gif_size += (size_t)n;
        }
        close(fd);

        if (truevision_patch && gif_size <= TRUEVISION_MIN_GIF_SIZE) {
            unlink(filename);
            continue;
        }

        sixel_encoder_t *encoder;
        SIXELSTATUS status = sixel_encoder_new(&encoder, NULL);
        if (status != SIXEL_OK) {
            continue;
        }

        /* Suppress output */
        set_option(encoder, SIXEL_OPTFLAG_OUTFILE, "/dev/null");
        set_flag(encoder, SIXEL_OPTFLAG_IGNORE_DELAY);

        /* Byte 0: color mode. Keep color-count options out of conflicting modes. */
        switch (control[0] & 0x03) {
        case 0: {
            const char *colors[] = {"2", "4", "8", "16", "32", "64", "128", "256"};
            set_option(encoder, SIXEL_OPTFLAG_COLORS, colors[control[1] & 0x07]);
            break;
        }
        case 1:
            set_flag(encoder, SIXEL_OPTFLAG_HIGH_COLOR);
            break;
        case 2:
            set_flag(encoder, SIXEL_OPTFLAG_MONOCHROME);
            break;
        case 3: {
            const char *palettes[] = {
                "xterm16", "xterm256", "vt340mono", "vt340color",
                "gray1", "gray2", "gray4", "gray8"
            };
            set_option(encoder, SIXEL_OPTFLAG_BUILTIN_PALETTE,
                       palettes[(control[1] >> 3) & 0x07]);
            break;
        }
        }

        const char *bgcolors[] = {NULL, "#000000", "#FFFFFF", "#FF0000"};
        int bg_idx = (control[0] >> 2) & 0x03;
        if (bgcolors[bg_idx]) {
            set_option(encoder, SIXEL_OPTFLAG_BGCOLOR, bgcolors[bg_idx]);
        }

        /* Byte 2: quality and diffusion. */
        const char *qualities[] = {"auto", "high", "low", "full"};
        set_option(encoder, SIXEL_OPTFLAG_QUALITY, qualities[control[2] & 0x03]);

        const char *diffusions[] = {
            "auto", "none", "fs", "atkinson", "jajuni",
            "stucki", "burkes", "a_dither", "x_dither"
        };
        set_option(encoder, SIXEL_OPTFLAG_DIFFUSION, diffusions[(control[2] >> 2) % 9]);

        /* Byte 3: palette type and quantization methods. */
        const char *palette_types[] = {"rgb", "hls"};
        set_option(encoder, SIXEL_OPTFLAG_PALETTE_TYPE, palette_types[control[3] & 0x01]);

        const char *largest_methods[] = {"auto", "norm", "lum"};
        set_option(encoder, SIXEL_OPTFLAG_FIND_LARGEST,
                   largest_methods[(control[3] >> 1) % 3]);

        const char *rep_methods[] = {"auto", "center", "average", "histogram"};
        set_option(encoder, SIXEL_OPTFLAG_SELECT_COLOR,
                   rep_methods[(control[3] >> 3) & 0x03]);

        /* Byte 4: output policy and optional output flags. */
        const char *policies[] = {"auto", "fast", "size"};
        set_option(encoder, SIXEL_OPTFLAG_ENCODE_POLICY, policies[control[4] % 3]);
        if (control[4] & 0x04) {
            set_flag(encoder, SIXEL_OPTFLAG_8BIT_MODE);
        }
        if (control[4] & 0x08) {
            set_flag(encoder, SIXEL_OPTFLAG_HAS_GRI_ARG_LIMIT);
        }
        if (control[4] & 0x10) {
            set_flag(encoder, SIXEL_OPTFLAG_INVERT);
        }
        if (control[4] & 0x40) {
            set_flag(encoder, SIXEL_OPTFLAG_STATIC);
        }

        /* Bytes 5-6: resizing, resampling, and crop ordering. */
        const char *resampling[] = {
            "nearest", "gaussian", "hanning", "hamming", "bilinear",
            "welsh", "bicubic", "lanczos2", "lanczos3", "lanczos4"
        };
        const char *sizes[] = {"1", "2", "4", "8", "16", "32", "64"};
        const char *crops[] = {"1x1+0+0", "2x2+0+0", "4x4+1+1", "8x8+0+0"};
        int resize_mode = (control[5] >> 4) & 0x03;
        int crop_mode = control[6] % 5;
        int crop_first = control[6] & 0x80;

        set_option(encoder, SIXEL_OPTFLAG_RESAMPLING, resampling[control[5] % 10]);

        if (crop_first) {
            if (crop_mode != 0) {
                set_option(encoder, SIXEL_OPTFLAG_CROP, crops[crop_mode - 1]);
            }
            if (resize_mode == 1) {
                set_option(encoder, SIXEL_OPTFLAG_WIDTH, sizes[control[5] % 7]);
            } else if (resize_mode == 2) {
                set_option(encoder, SIXEL_OPTFLAG_HEIGHT, sizes[(control[5] >> 1) % 7]);
            } else if (resize_mode == 3) {
                set_option(encoder, SIXEL_OPTFLAG_WIDTH, sizes[control[5] % 7]);
                set_option(encoder, SIXEL_OPTFLAG_HEIGHT, sizes[(control[5] >> 1) % 7]);
            }
        } else {
            if (resize_mode == 1) {
                set_option(encoder, SIXEL_OPTFLAG_WIDTH, sizes[control[5] % 7]);
            } else if (resize_mode == 2) {
                set_option(encoder, SIXEL_OPTFLAG_HEIGHT, sizes[(control[5] >> 1) % 7]);
            } else if (resize_mode == 3) {
                set_option(encoder, SIXEL_OPTFLAG_WIDTH, sizes[control[5] % 7]);
                set_option(encoder, SIXEL_OPTFLAG_HEIGHT, sizes[(control[5] >> 1) % 7]);
            }
            if (crop_mode != 0) {
                set_option(encoder, SIXEL_OPTFLAG_CROP, crops[crop_mode - 1]);
            }
        }

        /* Byte 7: animation and macro-related features. */
        const char *loops[] = {"auto", "force", "disable"};
        char macro_number[4];
        set_option(encoder, SIXEL_OPTFLAG_LOOPMODE, loops[control[7] % 3]);
        if (control[7] & 0x04) {
            set_flag(encoder, SIXEL_OPTFLAG_USE_MACRO);
        }
        if (control[7] & 0x08) {
            snprintf(macro_number, sizeof(macro_number), "%u", (unsigned int)((control[7] >> 4) & 0x0f));
            set_option(encoder, SIXEL_OPTFLAG_MACRO_NUMBER, macro_number);
        }

        /* This function decodes the input image and encodes it to SIXEL */
        sixel_encoder_encode(encoder, filename);

        sixel_encoder_unref(encoder);
    }

    unlink(filename);
    return 0;
}
