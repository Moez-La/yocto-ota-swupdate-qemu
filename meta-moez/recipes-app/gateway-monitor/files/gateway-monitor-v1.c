#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define VERSION "1.0.0"

char active_slot[4];

void get_slot() {
    FILE *fp = fopen("/proc/cmdline", "r");
    char buf[512];
    if (!fp) { strcpy(active_slot, "?"); return; }
    fgets(buf, sizeof(buf), fp);
    fclose(fp);
    if (strstr(buf, "vda2"))
        strcpy(active_slot, "A");
    else if (strstr(buf, "vda3"))
        strcpy(active_slot, "B");
    else
        strcpy(active_slot, "?");
}

void print_header() {
    printf("\n================================\n");
    printf("   EMBEDDED NETWORK GATEWAY\n");
    printf("   Version  : %s\n", VERSION);
    printf("   Slot     : %s (active)\n", active_slot);
    printf("================================\n");
}

void get_uptime(char *buf) {
    FILE *fp = fopen("/proc/uptime", "r");
    if (!fp) { strcpy(buf, "N/A"); return; }
    double uptime; fscanf(fp, "%lf", &uptime); fclose(fp);
    sprintf(buf, "%02d:%02d:%02d",
        (int)uptime/3600, ((int)uptime%3600)/60, (int)uptime%60);
}

void get_ip(char *buf) {
    FILE *fp = popen("ip addr show eth0 | grep 'inet ' | awk '{print $2}'", "r");
    if (!fp) { strcpy(buf, "N/A"); return; }
    fgets(buf, 64, fp); buf[strcspn(buf, "\n")] = 0; pclose(fp);
}

void get_rx_tx(long *rx, long *tx) {
    FILE *fp = fopen("/proc/net/dev", "r");
    char line[256];
    if (!fp) { *rx=0; *tx=0; return; }
    while (fgets(line, sizeof(line), fp))
        if (strstr(line, "eth0")) {
            sscanf(line+strcspn(line,":")+1,
                "%ld %*d %*d %*d %*d %*d %*d %*d %ld", rx, tx);
            break;
        }
    fclose(fp);
}

int main() {
    char uptime[32], ip[64];
    long rx, tx;

    get_slot();
    print_header();

    while (1) {
        get_uptime(uptime);
        get_ip(ip);
        get_rx_tx(&rx, &tx);

        printf("[%s] IP        : %s\n", uptime, ip);
        printf("[%s] eth0 RX   : %ld bytes\n", uptime, rx);
        printf("[%s] eth0 TX   : %ld bytes\n", uptime, tx);
        printf("[%s] STATUS    : NOMINAL\n", uptime);
        printf("--------------------------------\n");
        sleep(3);
    }
    return 0;
}
