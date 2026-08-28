#import "SNSymbolScan.h"

#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <string.h>

/// The __LINKEDIT slide needed to turn a symbol table file offset into an
/// address in this process.
///
/// A Mach-O records the symbol table as an offset into the file. Once loaded,
/// __LINKEDIT holds that data, and the difference between its virtual address
/// and its file offset is what converts one to the other.
static BOOL SNLinkeditBase(const struct mach_header_64 *header,
                           intptr_t slide,
                           uintptr_t *base) {
    const struct load_command *command =
        (const struct load_command *)((uintptr_t)header + sizeof(struct mach_header_64));

    for (uint32_t index = 0; index < header->ncmds; index++) {
        if (command->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *segment =
                (const struct segment_command_64 *)command;
            if (strcmp(segment->segname, SEG_LINKEDIT) == 0) {
                *base = (uintptr_t)slide + segment->vmaddr - segment->fileoff;
                return YES;
            }
        }
        command = (const struct load_command *)((uintptr_t)command + command->cmdsize);
    }
    return NO;
}

static const struct symtab_command *SNSymbolTable(const struct mach_header_64 *header) {
    const struct load_command *command =
        (const struct load_command *)((uintptr_t)header + sizeof(struct mach_header_64));

    for (uint32_t index = 0; index < header->ncmds; index++) {
        if (command->cmd == LC_SYMTAB) {
            return (const struct symtab_command *)command;
        }
        command = (const struct load_command *)((uintptr_t)command + command->cmdsize);
    }
    return NULL;
}

NSArray<NSString *> *SNSymbolsMatching(NSString *imageNameFragment,
                                       NSArray<NSString *> *keywords,
                                       NSUInteger limit) {
    NSMutableArray<NSString *> *matches = [NSMutableArray array];
    if (imageNameFragment.length == 0 || keywords.count == 0) {
        return matches;
    }

    for (uint32_t imageIndex = 0; imageIndex < _dyld_image_count(); imageIndex++) {
        const char *rawPath = _dyld_get_image_name(imageIndex);
        if (rawPath == NULL || strstr(rawPath, imageNameFragment.UTF8String) == NULL) {
            continue;
        }

        const struct mach_header_64 *header =
            (const struct mach_header_64 *)_dyld_get_image_header(imageIndex);
        if (header == NULL || header->magic != MH_MAGIC_64) {
            continue;
        }

        intptr_t slide = _dyld_get_image_vmaddr_slide(imageIndex);
        const struct symtab_command *symtab = SNSymbolTable(header);
        uintptr_t linkedit = 0;
        if (symtab == NULL || !SNLinkeditBase(header, slide, &linkedit)) {
            [matches addObject:[NSString stringWithFormat:
                @"%s: no symbol table in this image", rawPath]];
            continue;
        }

        const struct nlist_64 *symbols =
            (const struct nlist_64 *)(linkedit + symtab->symoff);
        const char *strings = (const char *)(linkedit + symtab->stroff);

        for (uint32_t index = 0; index < symtab->nsyms && matches.count < limit; index++) {
            uint32_t offset = symbols[index].n_un.n_strx;
            if (offset == 0 || offset >= symtab->strsize) {
                continue;
            }
            const char *name = strings + offset;
            if (name[0] == '\0') {
                continue;
            }

            for (NSString *keyword in keywords) {
                if (strstr(name, keyword.UTF8String) != NULL) {
                    [matches addObject:[NSString stringWithUTF8String:name] ?: @"(unreadable)"];
                    break;
                }
            }
        }
    }

    return matches;
}
