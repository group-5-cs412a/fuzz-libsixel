#include <sixel.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>

/*
 * Optimized Persistent Mode Harness for libsixel
 */

int main(int argc, char *argv[]) {
    // We will save the incoming bytes (after the flag byte) to a temp file
    char filename[256];
    snprintf(filename, sizeof(filename), "/dev/shm/fuzz_input_%d.gif", getpid());

    while (__AFL_LOOP(1000)) {
        // Rewind stdin, as afl-fuzz will feed the testcase here.
        lseek(STDIN_FILENO, 0, SEEK_SET);

        unsigned char flag_byte;
        ssize_t n = read(STDIN_FILENO, &flag_byte, 1);
        if (n <= 0) {
            continue;
        }

        int fd = open(filename, O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (fd < 0) {
            continue;
        }

        char buf[4096];
        while ((n = read(STDIN_FILENO, buf, sizeof(buf))) > 0) {
            write(fd, buf, n);
        }
        close(fd);

        sixel_encoder_t *encoder;
        SIXELSTATUS status = sixel_encoder_new(&encoder, NULL);
        if (status != SIXEL_OK) {
            continue;
        }

        /* Suppress output */
        sixel_encoder_setopt(encoder, SIXEL_OPTFLAG_OUTFILE, "/dev/null");
        
        /* Limit colors to 16 for speed */
        sixel_encoder_setopt(encoder, SIXEL_OPTFLAG_COLORS, "16");

        /* Apply mutated flags based on flag_byte */
        
        /* Bits 0-1 (2 bits): Quality */
        const char *qualities[] = {"auto", "high", "low", "full"};
        sixel_encoder_setopt(encoder, SIXEL_OPTFLAG_QUALITY, qualities[flag_byte & 0x03]);

        /* Bits 2-4 (3 bits): Diffusion */
        const char *diffusions[] = {"auto", "none", "fs", "atkinson", "jajuni", "stucki", "burkes", "a_dither"};
        sixel_encoder_setopt(encoder, SIXEL_OPTFLAG_DIFFUSION, diffusions[(flag_byte >> 2) & 0x07]);

        /* Bits 5-6 (2 bits): Background Color */
        const char *bgcolors[] = {NULL, "#000000", "#FFFFFF", "#FF0000"};
        int bg_idx = (flag_byte >> 5) & 0x03;
        if (bgcolors[bg_idx]) {
            sixel_encoder_setopt(encoder, SIXEL_OPTFLAG_BGCOLOR, bgcolors[bg_idx]);
        }

        /* Bit 7 (1 bit): Encode Policy */
        const char *policies[] = {"fast", "auto"};
        sixel_encoder_setopt(encoder, SIXEL_OPTFLAG_ENCODE_POLICY, policies[(flag_byte >> 7) & 0x01]);

        /* This function decodes the input image and encodes it to SIXEL */
        sixel_encoder_encode(encoder, filename);

        sixel_encoder_unref(encoder);
    }

    unlink(filename);
    return 0;
}
