/*
 Flashcard Learning App (C)
 Features:
  - Spaced repetition using a queue rotation model (due_in + interval)
  - Tag-based search via a hash map (separate chaining)
  - Console interactive interface: add, practice, search, list, save/load, exit
  - Implemented using Queues and Hash Maps (DSA concepts)

 Compile:
   gcc -std=c11 -O2 -o flashcards flashcards.c

 Run:
   ./flashcards
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define TAG_HASH_SIZE 1031    // prime-ish size for tag hash
#define MAX_TAGS 16
#define LINEBUF 4096

/* Utility: strdup for portability */
static char *my_strdup(const char *s) {
    if (!s) return NULL;
    size_t n = strlen(s) + 1;
    char *p = malloc(n);
    if (!p) { perror("malloc"); exit(1); }
    memcpy(p, s, n);
    return p;
}

/* --- Card structure --- */
typedef struct Card {
    int id;
    char *question;
    char *answer;
    char **tags;       // array of tag strings
    int tag_count;
    /* Spaced repetition fields */
    int interval;      // number of rotations to skip when answered correctly (>=1)
    int due_in;        // remaining rotations before this card is due (0 => due now)
    struct Card *next; // for linking lists
} Card;

/* --- Queue implementation (for scheduler) --- */
/* We'll use a simple linked queue of Card pointers. The queue stores all cards.
   The scheduler will simulate a "rotation": each rotation we pop head, decrement due_in,
   if due_in==0 then present it; otherwise we reenqueue it. When presenting, after
   user answers, we compute new interval/due_in and reenqueue. */

typedef struct QueueNode {
    Card *card;
    struct QueueNode *next;
} QueueNode;

typedef struct Queue {
    QueueNode *head, *tail;
    int size;
} Queue;

static Queue *queue_create(void) {
    Queue *q = malloc(sizeof(Queue));
    q->head = q->tail = NULL;
    q->size = 0;
    return q;
}

static void queue_enqueue(Queue *q, Card *c) {
    QueueNode *n = malloc(sizeof(QueueNode));
    n->card = c;
    n->next = NULL;
    if (!q->tail) q->head = q->tail = n;
    else {
        q->tail->next = n;
        q->tail = n;
    }
    q->size++;
}

static Card *queue_dequeue(Queue *q) {
    if (!q->head) return NULL;
    QueueNode *n = q->head;
    Card *c = n->card;
    q->head = n->next;
    if (!q->head) q->tail = NULL;
    free(n);
    q->size--;
    return c;
}

static int queue_is_empty(Queue *q) {
    return q->head == NULL;
}

/* iterate safely and free queue nodes (cards are freed separately) */
static void queue_free_nodes(Queue *q) {
    QueueNode *cur = q->head;
    while (cur) {
        QueueNode *nx = cur->next;
        free(cur);
        cur = nx;
    }
    q->head = q->tail = NULL;
    q->size = 0;
}

/* --- Hash map for tags: map tag string -> linked list of Card* --- */
typedef struct TagEntry {
    char *tag;
    Card *cards; // head of linked list of cards that have this tag (we'll append using Card.nextTag? Simpler: reuse Card.next - but can't. So we create card-list nodes)
    struct TagEntry *next;
} TagEntry;

/* To map tag to cards, we'll use a small wrapper list node */
typedef struct CardListNode {
    Card *card;
    struct CardListNode *next;
} CardListNode;

typedef struct TagEntry2 {
    char *tag;
    CardListNode *cards;
    struct TagEntry2 *next;
} TagEntry2;

static TagEntry2 *tag_map[TAG_HASH_SIZE];

static unsigned long str_hash(const char *s) {
    // djb2
    unsigned long h = 5381;
    int c;
    while ((c = *s++)) h = ((h << 5) + h) + (unsigned char)c;
    return h;
}

static TagEntry2 *tag_find(const char *tag) {
    unsigned long h = str_hash(tag) % TAG_HASH_SIZE;
    TagEntry2 *e = tag_map[h];
    while (e) {
        if (strcmp(e->tag, tag) == 0) return e;
        e = e->next;
    }
    return NULL;
}

static void tag_add_card(const char *tag, Card *card) {
    unsigned long h = str_hash(tag) % TAG_HASH_SIZE;
    TagEntry2 *e = tag_map[h];
    while (e) {
        if (strcmp(e->tag, tag) == 0) break;
        e = e->next;
    }
    if (!e) {
        e = malloc(sizeof(TagEntry2));
        e->tag = my_strdup(tag);
        e->cards = NULL;
        e->next = tag_map[h];
        tag_map[h] = e;
    }
    // append card to the front of card list (no duplicate checking for simplicity)
    CardListNode *cn = malloc(sizeof(CardListNode));
    cn->card = card;
    cn->next = e->cards;
    e->cards = cn;
}

/* When deleting a card, we should remove from tag lists.
   For simplicity, delete_card will remove card from maps by searching lists. */
static void tag_remove_card_from_tag_entry(TagEntry2 *e, Card *card) {
    CardListNode *prev = NULL, *cur = e->cards;
    while (cur) {
        if (cur->card == card) {
            if (prev) prev->next = cur->next;
            else e->cards = cur->next;
            free(cur);
            return;
        }
        prev = cur; cur = cur->next;
    }
}

static void tag_remove_card(Card *card) {
    // for each card tag, remove from tag map
    for (int i = 0; i < card->tag_count; ++i) {
        const char *t = card->tags[i];
        TagEntry2 *e = tag_find(t);
        if (e) {
            tag_remove_card_from_tag_entry(e, card);
            // optionally free tag entry if empty
            if (!e->cards) {
                unsigned long h = str_hash(e->tag) % TAG_HASH_SIZE;
                TagEntry2 *cur = tag_map[h], *prev = NULL;
                while (cur) {
                    if (cur == e) {
                        if (prev) prev->next = cur->next;
                        else tag_map[h] = cur->next;
                        free(cur->tag);
                        free(cur);
                        break;
                    }
                    prev = cur; cur = cur->next;
                }
            }
        }
    }
}

/* --- Card storage list --- */
static Card *cards_head = NULL;
static int next_card_id = 1;

/* create a card and add to global card list */
static Card *create_card(const char *q, const char *a, char **tags, int tag_count) {
    Card *c = malloc(sizeof(Card));
    c->id = next_card_id++;
    c->question = my_strdup(q);
    c->answer = my_strdup(a);
    c->tag_count = tag_count;
    c->tags = malloc(sizeof(char*) * tag_count);
    for (int i = 0; i < tag_count; ++i) c->tags[i] = my_strdup(tags[i]);
    c->interval = 1; // start with interval 1
    c->due_in = 0;    // due immediately when added
    c->next = NULL;
    // insert into cards list head
    c->next = cards_head;
    cards_head = c;
    // register tags
    for (int i = 0; i < tag_count; ++i) tag_add_card(tags[i], c);
    return c;
}

/* delete card permanently */
static void delete_card(Card *c) {
    if (!c) return;
    // remove from cards_head list
    Card *prev = NULL, *cur = cards_head;
    while (cur) {
        if (cur == c) {
            if (prev) prev->next = cur->next;
            else cards_head = cur->next;
            break;
        }
        prev = cur; cur = cur->next;
    }
    // remove from tag map
    tag_remove_card(c);
    // free memory
    free(c->question);
    free(c->answer);
    for (int i=0;i<c->tag_count;++i) free(c->tags[i]);
    free(c->tags);
    free(c);
}

/* --- Helper: trim whitespace and lower-case tag normalization --- */
static void trim_newline(char *s) {
    size_t n = strlen(s);
    while (n>0 && (s[n-1]=='\n' || s[n-1]=='\r')) { s[n-1] = '\0'; n--; }
}
static void str_ltrim(char *s) {
    char *p = s;
    while (*p && isspace((unsigned char)*p)) p++;
    if (p != s) memmove(s, p, strlen(p)+1);
}
static void str_rtrim(char *s) {
    int i = strlen(s)-1;
    while (i>=0 && isspace((unsigned char)s[i])) s[i--]='\0';
}
static void trim_whitespace(char *s) { str_ltrim(s); str_rtrim(s); }
static void normalize_tag(char *s) {
    trim_whitespace(s);
    for (char *p = s; *p; ++p) *p = (char)tolower((unsigned char)*p);
}

/* parse tags from a comma-separated string into allocated array */
static char **parse_tags(const char *line, int *out_count) {
    // copy then split
    char *tmp = my_strdup(line);
    char *p = tmp;
    char *tok;
    int cap = 8, cnt = 0;
    char **arr = malloc(sizeof(char*) * cap);
    while ((tok = strsep(&p, ",")) != NULL) {
        trim_whitespace(tok);
        if (strlen(tok) == 0) continue;
        normalize_tag(tok);
        if (cnt >= cap) { cap *= 2; arr = realloc(arr, sizeof(char*)*cap); }
        arr[cnt++] = my_strdup(tok);
    }
    free(tmp);
    *out_count = cnt;
    return arr;
}

/* --- Persistence: save/load simple text format --- */
static void save_cards_to_file(const char *filename) {
    FILE *f = fopen(filename, "w");
    if (!f) { perror("fopen"); return; }
    // simple format: card per block
    for (Card *c = cards_head; c; c = c->next) {
        fprintf(f, "ID=%d\n", c->id);
        fprintf(f, "Q=%s\n", c->question);
        fprintf(f, "A=%s\n", c->answer);
        fprintf(f, "T=");
        for (int i = 0; i < c->tag_count; ++i) {
            if (i) fprintf(f, ",");
            fprintf(f, "%s", c->tags[i]);
        }
        fprintf(f, "\n");
        fprintf(f, "I=%d\n", c->interval);
        fprintf(f, "D=%d\n", c->due_in);
        fprintf(f, "---\n");
    }
    fclose(f);
    printf("Saved %s\n", filename);
}

static void clear_all_data(Queue *q) {
    // clear tags
    for (int i=0;i<TAG_HASH_SIZE;++i) {
        TagEntry2 *e = tag_map[i];
        while (e) {
            TagEntry2 *nx = e->next;
            // free card list nodes
            CardListNode *cn = e->cards;
            while (cn) { CardListNode *cnx = cn->next; free(cn); cn = cnx; }
            free(e->tag);
            free(e);
            e = nx;
        }
        tag_map[i] = NULL;
    }
    // free cards
    Card *c = cards_head;
    while (c) {
        Card *nx = c->next;
        for (int i=0;i<c->tag_count;++i) free(c->tags[i]);
        free(c->tags);
        free(c->question);
        free(c->answer);
        free(c);
        c = nx;
    }
    cards_head = NULL;
    // free queue nodes
    if (q) queue_free_nodes(q);
}

/* Parsing helper: read file and reconstruct cards */
static void load_cards_from_file(const char *filename, Queue *q) {
    FILE *f = fopen(filename, "r");
    if (!f) { perror("fopen"); return; }
    clear_all_data(q);
    char line[LINEBUF];
    int id=0, interval=1, due=0;
    char *qtext=NULL, *atext=NULL, *tagsline=NULL;
    while (fgets(line, sizeof(line), f)) {
        trim_newline(line);
        if (strncmp(line, "ID=", 3) == 0) {
            id = atoi(line+3);
        } else if (strncmp(line, "Q=", 2) == 0) {
            free(qtext);
            qtext = my_strdup(line+2);
        } else if (strncmp(line, "A=", 2) == 0) {
            free(atext);
            atext = my_strdup(line+2);
        } else if (strncmp(line, "T=", 2) == 0) {
            free(tagsline);
            tagsline = my_strdup(line+2);
        } else if (strncmp(line, "I=", 2) == 0) {
            interval = atoi(line+2);
        } else if (strncmp(line, "D=", 2) == 0) {
            due = atoi(line+2);
        } else if (strcmp(line, "---") == 0) {
            if (qtext && atext) {
                int tcount=0;
                char **tks = parse_tags(tagsline?tagsline:"", &tcount);
                Card *c = create_card(qtext, atext, tks, tcount);
                c->interval = interval>0?interval:1;
                c->due_in = due>=0?due:0;
                // ensure next_card_id > id
                if (id >= next_card_id) next_card_id = id + 1;
                // enqueue into queue
                queue_enqueue(q, c);
                for (int i=0;i<tcount;++i) free(tks[i]);
                free(tks);
            }
            free(qtext); qtext=NULL;
            free(atext); atext=NULL;
            free(tagsline); tagsline=NULL;
            id = 0; interval=1; due=0;
        }
    }
    // catch last if no trailing ---
    if (qtext && atext) {
        int tcount=0; char **tks = parse_tags(tagsline?tagsline:"", &tcount);
        Card *c = create_card(qtext, atext, tks, tcount);
        c->interval = interval>0?interval:1;
        c->due_in = due>=0?due:0;
        if (id >= next_card_id) next_card_id = id + 1;
        queue_enqueue(q, c);
        for (int i=0;i<tcount;++i) free(tks[i]);
        free(tks);
    }
    free(qtext); free(atext); free(tagsline);
    fclose(f);
    printf("Loaded %s\n", filename);
}

/* --- Practice scheduler logic --- */
/* One rotation: we repeatedly dequeue until we find a card with due_in == 0,
   but to keep things fair we decrement due_in for cards that are ahead of schedule.
   Implementation: loop through queue nodes: we pop head, if due_in > 0, decrement and reenqueue.
   If due_in == 0, present; after handling, reenqueue with new due_in calculated.
*/

static void practice_loop(Queue *q) {
    if (!q || q->size == 0) {
        printf("No cards in the queue. Add some first.\n");
        return;
    }
    printf("Starting practice. Enter 'q' at any prompt to stop practicing.\n");
    int cont = 1;
    while (cont) {
        // search for next due card. But to avoid infinite loop if no due card,
        // we will process up to q->size nodes to find one due; if none due, decrement all due_in and continue.
        int scanned = 0;
        Card *c = NULL;
        int initial_size = q->size;
        while (scanned < initial_size) {
            Card *card = queue_dequeue(q);
            if (!card) break;
            if (card->due_in > 0) {
                card->due_in -= 1;
                queue_enqueue(q, card);
            } else {
                c = card;
                break;
            }
            scanned++;
        }
        if (!c) {
            // none were due; if queue still has elements, continue next rotation
            if (q->size == 0) { printf("Queue empty.\n"); return; }
            // else continue to next loop iteration to attempt again
            continue;
        }
        // Present card c
        printf("\n---\nCard #%d\nQ: %s\n(press Enter to see answer, 'q' to stop)\n", c->id, c->question);
        char cmd[16];
        if (!fgets(cmd, sizeof(cmd), stdin)) return;
        trim_newline(cmd);
        if (strcmp(cmd, "q") == 0) {
            // reenqueue the card unchanged and stop
            queue_enqueue(q, c);
            break;
        }
        printf("A: %s\n", c->answer);
        printf("Did you answer correctly? (y/n) or 'q' to stop: ");
        if (!fgets(cmd, sizeof(cmd), stdin)) return;
        trim_newline(cmd);
        if (strcmp(cmd, "q") == 0) { queue_enqueue(q, c); break; }
        if (cmd[0] == 'y' || cmd[0] == 'Y') {
            // correct: increase interval (double), set due_in = interval (skip that many rotations)
            c->interval = c->interval * 2;
            if (c->interval < 1) c->interval = 1;
            c->due_in = c->interval;
            printf("Nice! Interval now %d rotations.\n", c->interval);
        } else {
            // incorrect: reset interval to 1 and set due_in = 1 (show soon)
            c->interval = 1;
            c->due_in = 1;
            printf("Keep practicing — interval reset to 1.\n");
        }
        // reenqueue
        queue_enqueue(q, c);
    }
    printf("Exiting practice.\n");
}

/* --- User interface helpers --- */
static void list_all_cards(void) {
    if (!cards_head) { printf("No cards.\n"); return; }
    printf("All cards:\n");
    for (Card *c = cards_head; c; c = c->next) {
        printf("ID %d: Q: %.60s", c->id, c->question);
        if (strlen(c->question) > 60) printf("...");
        printf(" | tags:");
        for (int i=0;i<c->tag_count;++i) {
            printf(" %s", c->tags[i]);
        }
        printf(" | interval=%d due_in=%d\n", c->interval, c->due_in);
    }
}

static void search_by_tag(const char *tag) {
    char nt[256];
    strncpy(nt, tag, sizeof(nt)-1); nt[sizeof(nt)-1]=0;
    normalize_tag(nt);
    TagEntry2 *e = tag_find(nt);
    if (!e || !e->cards) {
        printf("No cards found for tag '%s'\n", nt);
        return;
    }
    printf("Cards with tag '%s':\n", nt);
    CardListNode *cn = e->cards;
    while (cn) {
        Card *c = cn->card;
        printf("ID %d: Q: %s | tags:", c->id, c->question);
        for (int i=0;i<c->tag_count;++i) printf(" %s", c->tags[i]);
        printf(" | interval=%d due_in=%d\n", c->interval, c->due_in);
        cn = cn->next;
    }
}

/* find card by id */
static Card *find_card_by_id(int id) {
    for (Card *c = cards_head; c; c = c->next) if (c->id == id) return c;
    return NULL;
}

/* add a card and enqueue */
static void add_card_interactive(Queue *q) {
    char buf[LINEBUF];
    printf("Enter question (single line):\n");
    if (!fgets(buf, sizeof(buf), stdin)) return;
    trim_newline(buf);
    if (strlen(buf) == 0) { printf("Empty question — cancelled.\n"); return; }
    char *qtext = my_strdup(buf);
    printf("Enter answer (single line):\n");
    if (!fgets(buf, sizeof(buf), stdin)) { free(qtext); return; }
    trim_newline(buf);
    char *atext = my_strdup(buf);
    printf("Enter tags (comma-separated, e.g., 'stack,queue'): \n");
    if (!fgets(buf, sizeof(buf), stdin)) { free(qtext); free(atext); return; }
    trim_newline(buf);
    int tcount=0;
    char **tks = parse_tags(buf, &tcount);
    Card *c = create_card(qtext, atext, tks, tcount);
    // new cards are due immediately
    c->due_in = 0;
    queue_enqueue(q, c);
    printf("Added card ID %d\n", c->id);
    free(qtext); free(atext);
    for (int i=0;i<tcount;++i) free(tks[i]);
    free(tks);
}

/* remove card interactive */
static void remove_card_interactive(Queue *q) {
    char buf[64];
    printf("Enter card ID to delete: ");
    if (!fgets(buf,sizeof(buf),stdin)) return;
    int id = atoi(buf);
    Card *c = find_card_by_id(id);
    if (!c) { printf("No card with ID %d\n", id); return; }
    // also need to remove it from queue nodes: rebuild queue skipping this card
    QueueNode *cur = q->head;
    QueueNode *new_head = NULL, *new_tail = NULL;
    while (cur) {
        if (cur->card != c) {
            QueueNode *n = malloc(sizeof(QueueNode));
            n->card = cur->card; n->next = NULL;
            if (!new_tail) new_head = new_tail = n;
            else { new_tail->next = n; new_tail = n; }
        }
        QueueNode *nx = cur->next;
        free(cur);
        cur = nx;
    }
    q->head = new_head; q->tail = new_tail;
    // remove card from global lists and free
    delete_card(c);
    // recompute queue size
    int sz = 0; for (QueueNode *n = q->head; n; n = n->next) ++sz;
    q->size = sz;
    printf("Deleted card #%d\n", id);
}

/* load sample data */
static void load_sample_cards(Queue *q) {
    char *t1[] = {"queue", "ds"};
    char *t2[] = {"hashmap", "ds"};
    char *t3[] = {"queue","srs"};
    create_card("What is FIFO in queues?", "First In First Out", t1, 2);
    create_card("How to handle collisions in hash map?", "Use chaining (linked lists) or open addressing", t2, 2);
    create_card("What is enqueue operation?", "Insert element at the tail of queue", t3, 2);
    // enqueue all cards to queue (we'll traverse cards_head)
    for (Card *c = cards_head; c; c = c->next) queue_enqueue(q, c);
}

/* --- Main interactive loop --- */
int main(void) {
    Queue *q = queue_create();
    char line[LINEBUF];
    printf("Flashcard App (C) — Queues + Hash Map demo\n");
    printf("Loading sample cards...\n");
    load_sample_cards(q);

    for (;;) {
        printf("\nMenu:\n");
        printf(" 1) Practice\n");
        printf(" 2) Add card\n");
        printf(" 3) Delete card\n");
        printf(" 4) Search by tag\n");
        printf(" 5) List all cards\n");
        printf(" 6) Save to file\n");
        printf(" 7) Load from file\n");
        printf(" 8) Exit\n");
        printf("Choose option: ");
        if (!fgets(line, sizeof(line), stdin)) break;
        trim_newline(line);
        if (strcmp(line, "1") == 0) {
            practice_loop(q);
        } else if (strcmp(line, "2") == 0) {
            add_card_interactive(q);
        } else if (strcmp(line, "3") == 0) {
            remove_card_interactive(q);
        } else if (strcmp(line, "4") == 0) {
            printf("Enter tag to search: ");
            if (!fgets(line, sizeof(line), stdin)) break;
            trim_newline(line);
            search_by_tag(line);
        } else if (strcmp(line, "5") == 0) {
            list_all_cards();
        } else if (strcmp(line, "6") == 0) {
            printf("Enter filename to save: ");
            if (!fgets(line, sizeof(line), stdin)) break;
            trim_newline(line);
            save_cards_to_file(line);
        } else if (strcmp(line, "7") == 0) {
            printf("Enter filename to load: ");
            if (!fgets(line, sizeof(line), stdin)) break;
            trim_newline(line);
            load_cards_from_file(line, q);
        } else if (strcmp(line, "8") == 0) {
            break;
        } else {
            printf("Unknown option.\n");
        }
    }

    // cleanup
    clear_all_data(q);
    free(q);
    printf("Goodbye.\n");
    return 0;
}
