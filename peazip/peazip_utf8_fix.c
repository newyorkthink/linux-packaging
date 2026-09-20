#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef void (*copy_unicode_fn)(const uint16_t *, void *, int);
typedef uint16_t *(*unicode_of_fn)(void *);
typedef int (*length_of_fn)(void *);
typedef void (*initialize_fn)(void **);
typedef void (*finalize_fn)(void **);
typedef void (*init_wide_strings_fn)(copy_unicode_fn, unicode_of_fn, length_of_fn,
                                     initialize_fn, finalize_fn);

static unicode_of_fn original_unicode_of;
static length_of_fn original_length_of;

static __thread uint16_t *fixed_text;
static __thread size_t fixed_capacity;
static __thread void *fixed_source;
static __thread int fixed_length;
static __thread int fixed_active;

/* Recover the byte value represented by a Latin-1 or CP1252 code point. */
static int cp1252_byte(uint16_t codepoint, unsigned char *result)
{
  static const struct {
    uint16_t codepoint;
    unsigned char byte;
  } mappings[] = {
    {0x20ac, 0x80}, {0x201a, 0x82}, {0x0192, 0x83}, {0x201e, 0x84},
    {0x2026, 0x85}, {0x2020, 0x86}, {0x2021, 0x87}, {0x02c6, 0x88},
    {0x2030, 0x89}, {0x0160, 0x8a}, {0x2039, 0x8b}, {0x0152, 0x8c},
    {0x017d, 0x8e}, {0x2018, 0x91}, {0x2019, 0x92}, {0x201c, 0x93},
    {0x201d, 0x94}, {0x2022, 0x95}, {0x2013, 0x96}, {0x2014, 0x97},
    {0x02dc, 0x98}, {0x2122, 0x99}, {0x0161, 0x9a}, {0x203a, 0x9b},
    {0x0153, 0x9c}, {0x017e, 0x9e}, {0x0178, 0x9f}
  };
  size_t index;

  if (codepoint <= 0xff) {
    *result = (unsigned char)codepoint;
    return 1;
  }
  for (index = 0; index < sizeof(mappings) / sizeof(mappings[0]); index++) {
    if (mappings[index].codepoint == codepoint) {
      *result = mappings[index].byte;
      return 1;
    }
  }
  return 0;
}

static int ensure_fixed_capacity(size_t units)
{
  uint16_t *new_text;

  if (units <= fixed_capacity)
    return 1;
  new_text = realloc(fixed_text, units * sizeof(*new_text));
  if (new_text == NULL)
    return 0;
  fixed_text = new_text;
  fixed_capacity = units;
  return 1;
}

/*
 * Only transform a complete, strictly valid UTF-8 byte sequence represented
 * as Latin-1/CP1252 Unicode. Correct Unicode and ordinary text pass through.
 */
static int decode_mojibake(const uint16_t *source, int source_length)
{
  unsigned char *bytes;
  size_t input_index;
  size_t output_index = 0;
  int saw_multibyte = 0;

  if (source == NULL || source_length <= 0)
    return 0;

  bytes = malloc((size_t)source_length);
  if (bytes == NULL)
    return 0;
  for (input_index = 0; input_index < (size_t)source_length; input_index++) {
    if (!cp1252_byte(source[input_index], &bytes[input_index])) {
      free(bytes);
      return 0;
    }
  }

  if (!ensure_fixed_capacity((size_t)source_length + 1)) {
    free(bytes);
    return 0;
  }

  input_index = 0;
  while (input_index < (size_t)source_length) {
    uint32_t codepoint;
    size_t sequence_length;
    unsigned char first = bytes[input_index];

    if (first < 0x80) {
      codepoint = first;
      sequence_length = 1;
    } else if (first >= 0xc2 && first <= 0xdf) {
      codepoint = first & 0x1f;
      sequence_length = 2;
    } else if (first >= 0xe0 && first <= 0xef) {
      codepoint = first & 0x0f;
      sequence_length = 3;
    } else if (first >= 0xf0 && first <= 0xf4) {
      codepoint = first & 0x07;
      sequence_length = 4;
    } else {
      free(bytes);
      return 0;
    }

    if (input_index + sequence_length > (size_t)source_length) {
      free(bytes);
      return 0;
    }
    if (sequence_length > 1)
      saw_multibyte = 1;

    for (size_t offset = 1; offset < sequence_length; offset++) {
      unsigned char continuation = bytes[input_index + offset];
      if ((continuation & 0xc0) != 0x80) {
        free(bytes);
        return 0;
      }
      codepoint = (codepoint << 6) | (continuation & 0x3f);
    }

    if ((sequence_length == 3 && codepoint < 0x800) ||
        (sequence_length == 4 && codepoint < 0x10000) ||
        (codepoint >= 0xd800 && codepoint <= 0xdfff) || codepoint > 0x10ffff) {
      free(bytes);
      return 0;
    }

    if (codepoint <= 0xffff) {
      fixed_text[output_index++] = (uint16_t)codepoint;
    } else {
      codepoint -= 0x10000;
      fixed_text[output_index++] = (uint16_t)(0xd800 + (codepoint >> 10));
      fixed_text[output_index++] = (uint16_t)(0xdc00 + (codepoint & 0x3ff));
    }
    input_index += sequence_length;
  }
  free(bytes);

  if (!saw_multibyte)
    return 0;
  fixed_text[output_index] = 0;
  fixed_length = (int)output_index;
  return 1;
}

/* C++ does not define which setUtf16 argument is evaluated first. */
static void prepare_fixed_text(void *wide_string)
{
  uint16_t *source = original_unicode_of(wide_string);
  int source_length = original_length_of(wide_string);

  fixed_active = decode_mojibake(source, source_length);
  fixed_source = fixed_active ? wide_string : NULL;
}

static uint16_t *fixed_unicode_of(void *wide_string)
{
  prepare_fixed_text(wide_string);
  return fixed_active ? fixed_text : original_unicode_of(wide_string);
}

static int fixed_length_of(void *wide_string)
{
  prepare_fixed_text(wide_string);
  return fixed_active && wide_string == fixed_source
           ? fixed_length
           : original_length_of(wide_string);
}

/* Do not leak this PeaZip-only preload into 7z or other child programs. */
__attribute__((constructor)) static void restore_child_preload(void)
{
  const char *original = getenv("PEAZIP_ORIGINAL_LD_PRELOAD");

  if (original != NULL && original[0] != '\0')
    setenv("LD_PRELOAD", original, 1);
  else
    unsetenv("LD_PRELOAD");
  unsetenv("PEAZIP_ORIGINAL_LD_PRELOAD");
}

/* Replace the one Pascal WideString-to-Qt QString boundary used by Qt6Pas. */
void initPWideStrings(copy_unicode_fn copy_unicode, unicode_of_fn unicode_of,
                      length_of_fn length_of, initialize_fn initialize,
                      finalize_fn finalize)
{
  init_wide_strings_fn real_init = NULL;
  const char *error;

  dlerror();
  *(void **)(&real_init) = dlsym(RTLD_NEXT, "initPWideStrings");
  error = dlerror();
  if (error != NULL || real_init == NULL) {
    static const char message[] =
      "PeaZip UTF-8 compatibility library cannot find Qt6Pas initPWideStrings\n";
    ssize_t written = write(STDERR_FILENO, message, sizeof(message) - 1);
    (void)written;
    _exit(127);
  }

  original_unicode_of = unicode_of;
  original_length_of = length_of;
  real_init(copy_unicode, fixed_unicode_of, fixed_length_of, initialize, finalize);
}
