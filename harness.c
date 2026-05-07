#include <sixel.h>
#include <stdlib.h>
#include <unistd.h>

/*
 * Optimized Persistent Mode Harness for libsixel
 */

int main(int argc, char *argv[]) {
    sixel_encoder_t *encoder;
    SIXELSTATUS status;

    /* Initialize encoder once */
    status = sixel_encoder_new(&encoder, NULL);
    if (status != SIXEL_OK) {
        return 1;
    }

    /* 
     * SPEED OPTIMIZATIONS:
     * We use the correct flag names found in libsixel's header.
     */
    
    /* Suppress output */
    sixel_encoder_setopt(encoder, SIXEL_OPTFLAG_OUTFILE, "/dev/null");
    
    /* Disable dithering (huge speed boost) */
    sixel_encoder_setopt(encoder, SIXEL_OPTFLAG_DIFFUSION, "none");
    
    /* Use the fastest encoding policy */
    sixel_encoder_setopt(encoder, SIXEL_OPTFLAG_ENCODE_POLICY, "fast");
    
    /* Use low quality for quantization to save CPU */
    sixel_encoder_setopt(encoder, SIXEL_OPTFLAG_QUALITY, "low");
    
    /* Limit colors to 16 */
    sixel_encoder_setopt(encoder, SIXEL_OPTFLAG_COLORS, "16");

    while (__AFL_LOOP(1000)) {
        if (argc > 1) {
            /* This function decodes the input image and encodes it to SIXEL */
            sixel_encoder_encode(encoder, argv[1]);
        }
    }

    sixel_encoder_unref(encoder);
    return 0;
}
