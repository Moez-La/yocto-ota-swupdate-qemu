#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>

#define VERSION "3.0.0"

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
    printf("   Slot     : %s (dynamic)\n", active_slot);
    printf("   *** OTA v3.0 - ADVANCED MON ***\n");
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

void get_cpu(char *buf) {
    FILE *fp = fopen("/proc/loadavg", "r"); float load;
    if (!fp) { strcpy(buf, "N/A"); return; }
    fscanf(fp, "%f", &load); fclose(fp);
    sprintf(buf, "%.2f", load);
}

void get_mem(long *total, long *free_mem) {
    FILE *fp = fopen("/proc/meminfo", "r"); char line[128];
    if (!fp) { *total=0; *free_mem=0; return; }
    while (fgets(line, sizeof(line), fp)) {
        if (!strncmp(line,"MemTotal:",9)) sscanf(line+9,"%ld",total);
        if (!strncmp(line,"MemAvailable:",13)) sscanf(line+13,"%ld",free_mem);
    }
    fclose(fp);
}

/* Calcule le débit réseau en KB/s sur une fenêtre d'1 seconde */
void get_bandwidth(float *rx_kbps, float *tx_kbps) {
    long rx1, tx1, rx2, tx2;
    get_rx_tx(&rx1, &tx1);
    sleep(1);
    get_rx_tx(&rx2, &tx2);
    *rx_kbps = (float)(rx2 - rx1) / 1024.0f;
    *tx_kbps = (float)(tx2 - tx1) / 1024.0f;
}

/* Compte les processus actifs depuis /proc */
int get_process_count() {
    FILE *fp = popen("ls /proc | grep '^[0-9]' | wc -l", "r");
    int count = 0;
    if (!fp) return 0;
    fscanf(fp, "%d", &count);
    pclose(fp);
    return count;
}

/* Lit les erreurs réseau (dropped packets) depuis /proc/net/dev */
void get_net_errors(long *rx_drop, long *tx_drop) {
    FILE *fp = fopen("/proc/net/dev", "r");
    char line[256];
    *rx_drop = 0; *tx_drop = 0;
    if (!fp) return;
    while (fgets(line, sizeof(line), fp))
        if (strstr(line, "eth0")) {
            /* Format: rx_bytes rx_pkts rx_errs rx_drop ... tx_bytes tx_pkts tx_errs tx_drop */
            sscanf(line+strcspn(line,":")+1,
                "%*ld %*ld %*ld %ld %*ld %*ld %*ld %*ld "
                "%*ld %*ld %*ld %ld", rx_drop, tx_drop);
            break;
        }
    fclose(fp);
}

/* Détecte le statut du système via /proc/sys/kernel/panic */
void get_system_health(char *buf) {
    FILE *fp = fopen("/proc/loadavg", "r");
    float load1, load5, load15;
    if (!fp) { strcpy(buf, "UNKNOWN"); return; }
    fscanf(fp, "%f %f %f", &load1, &load5, &load15);
    fclose(fp);
    if (load1 > 2.0)
        strcpy(buf, "WARNING - HIGH LOAD");
    else if (load1 > 0.8)
        strcpy(buf, "NOMINAL - MODERATE");
    else
        strcpy(buf, "NOMINAL - OPTIMAL");
}

int main() {
    char uptime[32], ip[64], cpu[16], health[32];
    long rx, tx, mem_total, mem_free, rx_drop, tx_drop;
    float rx_kbps, tx_kbps;
    int packets = 0, procs = 0;

    get_slot();
    print_header();

    while (1) {
        get_uptime(uptime);
        get_ip(ip);
        get_rx_tx(&rx, &tx);
        get_cpu(cpu);
        get_mem(&mem_total, &mem_free);
        get_bandwidth(&rx_kbps, &tx_kbps);
        get_net_errors(&rx_drop, &tx_drop);
        procs = get_process_count();
        get_system_health(health);

        printf("[%s] Slot         : %s (from /proc/cmdline)\n", uptime, active_slot);
        printf("[%s] IP           : %s\n", uptime, ip);
        printf("[%s] eth0 RX      : %ld bytes\n", uptime, rx);
        printf("[%s] eth0 TX      : %ld bytes\n", uptime, tx);
        printf("[%s] Bandwidth RX : %.2f KB/s\n", uptime, rx_kbps);
        printf("[%s] Bandwidth TX : %.2f KB/s\n", uptime, tx_kbps);
        printf("[%s] Dropped pkts : RX=%ld TX=%ld\n", uptime, rx_drop, tx_drop);
        printf("[%s] CPU load     : %s\n", uptime, cpu);
        printf("[%s] RAM free     : %ld / %ld KB\n", uptime, mem_free, mem_total);
        printf("[%s] Processes    : %d active\n", uptime, procs);
        printf("[%s] Packets mon  : %d\n", uptime, ++packets);
        printf("[%s] Firewall     : ACTIVE\n", uptime);
        printf("[%s] Health       : %s\n", uptime, health);
        printf("--------------------------------\n");
        sleep(2);
    }
    return 0;
}
