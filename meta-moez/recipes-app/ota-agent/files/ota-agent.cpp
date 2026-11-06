#include <iostream>
#include <fstream>
#include <string>
#include <cstdlib>
#include <unistd.h>
#include <curl/curl.h>
#include <sys/stat.h>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

#define OTA_SERVER    "https://ota-server-liaa.onrender.com"
#define API_KEY_FILE  "/etc/ota-agent/api_key"

static std::string g_api_key;

static std::string read_api_key() {
    std::ifstream f(API_KEY_FILE);
    std::string key;
    std::getline(f, key);
    while (!key.empty() && (key.back() == '\r' || key.back() == ' '))
        key.pop_back();
    return key;
}
#define VERSION_FILE  "/var/lib/swupdate/ota-version"
#define SWU_PATH      "/ota/update.swu"
#define CHECK_INTERVAL 60

static size_t write_callback(void *ptr, size_t size, size_t nmemb, std::string *data) {
    data->append((char*)ptr, size * nmemb);
    return size * nmemb;
}

static size_t file_callback(void *ptr, size_t size, size_t nmemb, FILE *fp) {
    return fwrite(ptr, size, nmemb, fp);
}

std::string get_current_version() {
    std::ifstream f(VERSION_FILE);
    if (!f.is_open()) return "1.0.0";
    std::string ver;
    std::getline(f, ver);
    if (!ver.empty() && ver.back() == '\n') ver.pop_back();
    return ver.empty() ? "1.0.0" : ver;
}

bool check_update(const std::string &current_ver, std::string &new_ver) {
    CURL *curl = curl_easy_init();
    if (!curl) return false;

    std::string response;
    std::string url = std::string(OTA_SERVER) + "/version";

    struct curl_slist *headers = nullptr;
    headers = curl_slist_append(headers, ("x-api-key: " + g_api_key).c_str());
    headers = curl_slist_append(headers, ("x-current-version: " + current_ver).c_str());

    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 1L);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 30L);

    CURLcode res = curl_easy_perform(curl);
    long http_code = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);

    if (res != CURLE_OK || http_code != 200) {
        std::cerr << "[OTA] Server response: " << http_code << std::endl;
        return false;
    }

    try {
        auto j = json::parse(response);
        if (j.contains("update_available") && j["update_available"] == false) {
            std::cout << "[OTA] Already up to date: " << current_ver << std::endl;
            return false;
        }
        new_ver = j["version"].get<std::string>();
        return true;
    } catch (...) {
        return false;
    }
}

bool download_firmware() {
    // Wake up Render server first
    std::cout << "[OTA] Waking up server..." << std::endl;
    CURL *wake = curl_easy_init();
    if (wake) {
        std::string health_url = std::string(OTA_SERVER) + "/health";
        std::string dummy;
        curl_easy_setopt(wake, CURLOPT_URL, health_url.c_str());
        curl_easy_setopt(wake, CURLOPT_WRITEFUNCTION, write_callback);
        curl_easy_setopt(wake, CURLOPT_WRITEDATA, &dummy);
        curl_easy_setopt(wake, CURLOPT_TIMEOUT, 60L);
        curl_easy_perform(wake);
        curl_easy_cleanup(wake);
        sleep(3);
    }

    CURL *curl = curl_easy_init();
    if (!curl) return false;

    FILE *fp = fopen(SWU_PATH, "wb");
    if (!fp) return false;

    std::string url = std::string(OTA_SERVER) + "/firmware";
    struct curl_slist *headers = nullptr;
    headers = curl_slist_append(headers, ("x-api-key: " + g_api_key).c_str());

    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, file_callback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, fp);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 1L);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 300L);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);

    CURLcode res = curl_easy_perform(curl);
    fclose(fp);
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);

    if (res != CURLE_OK) {
        std::cerr << "[OTA] curl error: " << curl_easy_strerror(res) << std::endl;
        return false;
    }

    // Verify file size (must be > 1MB)
    struct stat st;
    if (stat(SWU_PATH, &st) != 0 || st.st_size < 1024*1024) {
        std::cerr << "[OTA] Downloaded file too small: " << st.st_size << " bytes" << std::endl;
        return false;
    }

    std::cout << "[OTA] Downloaded " << st.st_size/1024/1024 << " MB" << std::endl;
    return true;
}

int main() {
    g_api_key = read_api_key();
    if (g_api_key.empty()) {
        std::cerr << "ota-agent: no API key in " << API_KEY_FILE << ", exiting" << std::endl;
        return 1;
    }
    std::cout << "[OTA] Agent started" << std::endl;
    system("mkdir -p /ota && mount -t tmpfs -o size=200M tmpfs /ota 2>/dev/null || true");
    system("killall swupdate 2>/dev/null; sleep 2");
    curl_global_init(CURL_GLOBAL_ALL);

    while (true) {
        std::string current = get_current_version();
        std::string new_ver;

        std::cout << "[OTA] Checking update (current: " << current << ")" << std::endl;

        if (check_update(current, new_ver)) {
            std::cout << "[OTA] New version available: " << new_ver << std::endl;
            std::cout << "[OTA] Downloading firmware..." << std::endl;

            if (download_firmware()) {
                std::cout << "[OTA] Download complete. Launching SWUpdate..." << std::endl;
                int ret = system("swupdate -m -M -i /ota/update.swu -k /etc/swupdate/swupdate-public.pem -H qemuarm:1.0");
                if (ret == 0) {
                    std::cout << "[OTA] SWUpdate success. Rebooting..." << std::endl;
                    system("reboot");
                } else {
                    std::cerr << "[OTA] SWUpdate failed: " << ret << std::endl;
                }
            } else {
                std::cerr << "[OTA] Download failed" << std::endl;
            }
        }

        std::cout << "[OTA] Next check in " << CHECK_INTERVAL << "s" << std::endl;
        sleep(CHECK_INTERVAL);
    }

    curl_global_cleanup();
    return 0;
}
