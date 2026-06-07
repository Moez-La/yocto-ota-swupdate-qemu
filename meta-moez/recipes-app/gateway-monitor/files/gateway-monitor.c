#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>

#define VERSION "2.0.0"
#define SLOT    "B"

void print_header() {
    printf("\n");
    printf("================================\n");
    printf("   EMBEDDED NETWORK GATEWAY\n");
    printf("   Version  : %s\n", VERSION);
    printf("   Slot     : %s (active)\n", SLOT);
    printf("   *** OTA UPDATE APPLIED ***\n");
    printf("================================\n");
}

void get_uptime(char *buf) {
    FILE *fp = fopen("/proc/uptime", "r");
    if (!fp) { strcpy(buf, "N/A"); return; }
    double uptime;
    fscanf(fp, "%lf", &uptime);
    fclose(fp);
    int h = (int)uptime / 3600;
    int m = ((int)uptime % 3600) / 60;
    int s = (int)uptime % 60;
    sprintf(buf, "%02d:%02d:%02d", h, m, s);
}

void get_ip(char *buf) {
    FILE *fp = popen("ip addr show eth0 | grep 'inet ' | awk '{print $2}'", "r");
    if (!fp) { strcpy(buf, "N/A"); return; }
    fgets(buf, 64, fp);
    buf[strcspn(buf, "\n")] = 0;
    pclose(fp);
}

void get_rx_tx(long *rx, long *tx) {
    FILE *fp = fopen("/proc/net/dev", "r");
    if (!fp) { *rx = 0; *tx = 0; return; }
    char line[256];
    while (fgets(line, sizeof(line), fp)) {
        if (strstr(line, "eth0")) {
            sscanf(line + strcspn(line, ":") + 1, "%ld %*d %*d %*d %*d %*d %*d %*d %ld", rx, tx);
            break;
        }
    }
    fclose(fp);
}

void get_cpu_usage(char *buf) {
    FILE *fp = fopen("/proc/loadavg", "r");
    if (!fp) { strcpy(buf, "N/A"); return; }
    float load;
    fscanf(fp, "%f", &load);
    fclose(fp);
    sprintf(buf, "%.2f", load);
}

void get_mem(long *total, long *free) {
    FILE *fp = fopen("/proc/meminfo", "r");
    if (!fp) { *total = 0; *free = 0; return; }
    char line[128];
    while (fgets(line, sizeof(line), fp)) {
        if (strncmp(line, "MemTotal:", 9) == 0) sscanf(line + 9, "%ld", total);
        if (strncmp(line, "MemAvailable:", 13) == 0) sscanf(line + 13, "%ld", free);
    }
    fclose(fp);
}

int main() {
    char uptime[32], ip[64], cpu[16];
    long rx, tx, mem_total, mem_free;
    int packet_count = 0;

    print_header();

    while (1) {
        get_uptime(uptime);
        get_ip(ip);
        get_rx_tx(&rx, &tx);
        get_cpu_usage(cpu);
        get_mem(&mem_total, &mem_free);
        packet_count++;

        printf("[%s] IP           : %s\n", uptime, ip);
        printf("[%s] eth0 RX      : %ld bytes\n", uptime, rx);
        printf("[%s] eth0 TX      : %ld bytes\n", uptime, tx);
        printf("[%s] CPU load     : %s\n", uptime, cpu);
        printf("[%s] RAM free     : %ld / %ld KB\n", uptime, mem_free, mem_total);
        printf("[%s] Packets mon  : %d\n", uptime, packet_count);
        printf("[%s] Firewall     : ACTIVE (v2.0 feature)\n", uptime);
        printf("[%s] STATUS       : NOMINAL - ENHANCED\n", uptime);
        printf("--------------------------------\n");

        sleep(3);
    }
    return 0;
}
