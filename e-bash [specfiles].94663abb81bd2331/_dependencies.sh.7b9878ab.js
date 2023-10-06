var data = {lines:[
{"lineNum":"    1","line":"#!/usr/bin/env bash"},
{"lineNum":"    2","line":"# shellcheck disable=SC2034"},
{"lineNum":"    3","line":""},
{"lineNum":"    4","line":"# shellcheck disable=SC1090 source=./_commons.sh"},
{"lineNum":"    5","line":"source \"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)/_commons.sh\"","class":"lineCov","hits":"4","order":"124","possible_hits":"0",},
{"lineNum":"    6","line":"# shellcheck disable=SC1090 source=./_logger.sh"},
{"lineNum":"    7","line":"source \"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)/_logger.sh\"","class":"lineCov","hits":"4","order":"125","possible_hits":"0",},
{"lineNum":"    8","line":""},
{"lineNum":"    9","line":"#set -x # Uncomment to DEBUG"},
{"lineNum":"   10","line":""},
{"lineNum":"   11","line":"# shellcheck disable=SC2001,SC2155,SC2046,SC2116"},
{"lineNum":"   12","line":"function isDebug() {"},
{"lineNum":"   13","line":"\tlocal args=(\"$@\")","class":"lineCov","hits":"4","order":"177","possible_hits":"0",},
{"lineNum":"   14","line":"\tif [[ \"${args[*]}\" =~ \"--debug\" ]]; then echo true; else echo false; fi","class":"lineCov","hits":"8","order":"178","possible_hits":"0",},
{"lineNum":"   15","line":"}"},
{"lineNum":"   16","line":""},
{"lineNum":"   17","line":"function isExec() {"},
{"lineNum":"   18","line":"\tlocal args=(\"$@\")","class":"lineCov","hits":"14","order":"132","possible_hits":"0",},
{"lineNum":"   19","line":"\tif [[ \"${args[*]}\" =~ \"--exec\" ]]; then echo true; else echo false; fi","class":"lineCov","hits":"28","order":"133","possible_hits":"0",},
{"lineNum":"   20","line":"}"},
{"lineNum":"   21","line":""},
{"lineNum":"   22","line":"function isOptional() {"},
{"lineNum":"   23","line":"\tlocal args=(\"$@\")","class":"lineCov","hits":"11","order":"135","possible_hits":"0",},
{"lineNum":"   24","line":"\tif [[ \"${args[*]}\" =~ \"--optional\" ]]; then echo true; else echo false; fi","class":"lineCov","hits":"22","order":"136","possible_hits":"0",},
{"lineNum":"   25","line":"}"},
{"lineNum":"   26","line":""},
{"lineNum":"   27","line":"function isSilent() {"},
{"lineNum":"   28","line":"\tlocal args=(\"$@\")","class":"lineCov","hits":"4","order":"174","possible_hits":"0",},
{"lineNum":"   29","line":"\tif [[ \"${args[*]}\" =~ \"--silent\" ]]; then echo true; else echo false; fi","class":"lineCov","hits":"8","order":"175","possible_hits":"0",},
{"lineNum":"   30","line":"}"},
{"lineNum":"   31","line":""},
{"lineNum":"   32","line":"# shellcheck disable=SC2001,SC2155,SC2086"},
{"lineNum":"   33","line":"function dependency() {"},
{"lineNum":"   34","line":"\tlocal tool_name=$1","class":"lineCov","hits":"10","order":"127","possible_hits":"0",},
{"lineNum":"   35","line":"\tlocal tool_version_pattern=$2","class":"lineCov","hits":"10","order":"128","possible_hits":"0",},
{"lineNum":"   36","line":"\tlocal tool_fallback=${3:-\"No details. Please google it.\"}","class":"lineCov","hits":"10","order":"129","possible_hits":"0",},
{"lineNum":"   37","line":"\tlocal tool_version_flag=${4:-\"--version\"}","class":"lineCov","hits":"10","order":"130","possible_hits":"0",},
{"lineNum":"   38","line":"\tlocal is_exec=$(isExec \"$@\")","class":"lineCov","hits":"20","order":"131","possible_hits":"0",},
{"lineNum":"   39","line":"\tlocal is_optional=$(isOptional \"$@\")","class":"lineCov","hits":"20","order":"134","possible_hits":"0",},
{"lineNum":"   40","line":""},
{"lineNum":"   41","line":"\tconfig:logger:Dependencies \"$@\" # refresh debug flags","class":"lineCov","hits":"10","order":"137","possible_hits":"0",},
{"lineNum":"   42","line":""},
{"lineNum":"   43","line":"\t# escape symbols: & / . { }, remove end of line, replace * by expectation from 1 to 4 digits"},
{"lineNum":"   44","line":"\tlocal tool_version=$(sed -e \'s#[&\\\\/\\.{}]#\\\\&#g; s#$#\\\\#\' -e \'$s#\\\\$##\' -e \'s#*#[0-9]\\\\{1,4\\\\}#g\' <<<$tool_version_pattern)","class":"lineCov","hits":"20","order":"138","possible_hits":"0",},
{"lineNum":"   45","line":""},
{"lineNum":"   46","line":"\t# try to find tool"},
{"lineNum":"   47","line":"\tlocal which_tool=$(command -v $tool_name)","class":"lineCov","hits":"20","order":"139","possible_hits":"0",},
{"lineNum":"   48","line":""},
{"lineNum":"   49","line":"\tif [ -z \"$which_tool\" ]; then","class":"lineCov","hits":"10","order":"140","possible_hits":"0",},
{"lineNum":"   50","line":"\t\tprintf:Dependencies \"which  : %s\\npattern: %s, sed: \\\"s#.*\\(%s\\).*#\\1#g\\\"\\n-------\\n\" \\","class":"lineCov","hits":"2","order":"159","possible_hits":"0",},
{"lineNum":"   51","line":"\t\t\t\"${which_tool:-\"command -v $tool_name\"}\" \"$tool_version_pattern\" \"$tool_version\""},
{"lineNum":"   52","line":""},
{"lineNum":"   53","line":"\t\tif $is_optional; then","class":"lineCov","hits":"2","order":"160","possible_hits":"0",},
{"lineNum":"   54","line":"\t\t\t# shellcheck disable=SC2154"},
{"lineNum":"   55","line":"\t\t\techo \"Optional   [${cl_red}NO${cl_reset}]: \\`$tool_name\\` - ${cl_red}not found${cl_reset}! Try: ${cl_purple}$tool_fallback${cl_reset}\"","class":"lineCov","hits":"1","order":"184","possible_hits":"0",},
{"lineNum":"   56","line":"\t\t\treturn 0","class":"lineCov","hits":"1","order":"185","possible_hits":"0",},
{"lineNum":"   57","line":"\t\telse"},
{"lineNum":"   58","line":"\t\t\techo \"${cl_red}Error: dependency \\`$tool_name\\` not found.\"","class":"lineCov","hits":"1","order":"161","possible_hits":"0",},
{"lineNum":"   59","line":"\t\t\techo \"${cl_reset} Hint. To install tool use the command below: \"","class":"lineCov","hits":"1","order":"162","possible_hits":"0",},
{"lineNum":"   60","line":"\t\t\techo \" \\$>  $tool_fallback\"","class":"lineCov","hits":"1","order":"163","possible_hits":"0",},
{"lineNum":"   61","line":"\t\t\treturn 1","class":"lineCov","hits":"1","order":"164","possible_hits":"0",},
{"lineNum":"   62","line":"\t\tfi"},
{"lineNum":"   63","line":"\tfi"},
{"lineNum":"   64","line":""},
{"lineNum":"   65","line":"\tlocal version_message=$($tool_name $tool_version_flag 2>&1)","class":"lineCov","hits":"16","order":"141","possible_hits":"0",},
{"lineNum":"   66","line":"\tlocal version_cleaned=$(echo \"\'$version_message\'\" | sed -n \"s#.*\\($tool_version\\).*#\\1#p\" | head -1)","class":"lineCov","hits":"32","order":"142","possible_hits":"0",},
{"lineNum":"   67","line":""},
{"lineNum":"   68","line":"\tprintf:Dependencies \"which  : %s\\nversion: %s\\npattern: %s, sed: \\\"s#.*\\(%s\\).*#\\1#g\\\"\\nver.   : %s\\n-------\\n\" \\","class":"lineCov","hits":"8","order":"143","possible_hits":"0",},
{"lineNum":"   69","line":"\t\t\"$which_tool\" \"$version_message\" \"$tool_version_pattern\" \"$tool_version\" \"$version_cleaned\""},
{"lineNum":"   70","line":""},
{"lineNum":"   71","line":"\tif [ \"$version_cleaned\" == \"\" ]; then","class":"lineCov","hits":"8","order":"144","possible_hits":"0",},
{"lineNum":"   72","line":"\t\tif $is_optional; then","class":"lineCov","hits":"3","order":"147","possible_hits":"0",},
{"lineNum":"   73","line":"\t\t\techo \"Optional   [${cl_red}NO${cl_reset}]: \\`$tool_name\\` - ${cl_red}wrong version${cl_reset}! Try: ${cl_purple}$tool_fallback${cl_reset}\"","class":"lineCov","hits":"1","order":"181","possible_hits":"0",},
{"lineNum":"   74","line":"\t\t\treturn 0","class":"lineCov","hits":"1","order":"182","possible_hits":"0",},
{"lineNum":"   75","line":"\t\telse"},
{"lineNum":"   76","line":"\t\t\techo \"${cl_red}Error: dependency version \\`$tool_name\\` is wrong.\"","class":"lineCov","hits":"2","order":"148","possible_hits":"0",},
{"lineNum":"   77","line":"\t\t\techo \" Extracted: \\`$version_cleaned\\`\"","class":"lineCov","hits":"2","order":"149","possible_hits":"0",},
{"lineNum":"   78","line":"\t\t\techo \" Expected : \\`$tool_version_pattern\\`${cl_reset}\"","class":"lineCov","hits":"2","order":"150","possible_hits":"0",},
{"lineNum":"   79","line":""},
{"lineNum":"   80","line":"\t\t\tif $is_exec; then","class":"lineCov","hits":"2","order":"151","possible_hits":"0",},
{"lineNum":"   81","line":"\t\t\t\t# shellcheck disable=SC2006,SC2154"},
{"lineNum":"   82","line":"\t\t\t\techo \" Executing: ${cl_yellow}${tool_fallback}${cl_reset}\"","class":"lineCov","hits":"1","order":"156","possible_hits":"0",},
{"lineNum":"   83","line":"\t\t\t\techo \"\"","class":"lineCov","hits":"1","order":"157","possible_hits":"0",},
{"lineNum":"   84","line":"\t\t\t\teval $tool_fallback","class":"lineCov","hits":"2","order":"158","possible_hits":"0",},
{"lineNum":"   85","line":"\t\t\telse"},
{"lineNum":"   86","line":"\t\t\t\techo \"\"","class":"lineCov","hits":"1","order":"152","possible_hits":"0",},
{"lineNum":"   87","line":"\t\t\t\techo \" Hint. To install tool use the command below: \"","class":"lineCov","hits":"1","order":"153","possible_hits":"0",},
{"lineNum":"   88","line":"\t\t\t\techo \" \\$>  $tool_fallback\"","class":"lineCov","hits":"1","order":"154","possible_hits":"0",},
{"lineNum":"   89","line":"\t\t\t\treturn 1","class":"lineCov","hits":"1","order":"155","possible_hits":"0",},
{"lineNum":"   90","line":"\t\t\tfi"},
{"lineNum":"   91","line":"\t\tfi"},
{"lineNum":"   92","line":"\telse"},
{"lineNum":"   93","line":"\t\tif $is_optional; then echo -n \"Optional   \"; else echo -n \"Dependency \"; fi","class":"lineCov","hits":"10","order":"145","possible_hits":"0",},
{"lineNum":"   94","line":"\t\t# shellcheck disable=SC2154"},
{"lineNum":"   95","line":"\t\techo \"[${cl_green}OK${cl_reset}]: \\`$tool_name\\` - version: $version_cleaned\"","class":"lineCov","hits":"5","order":"146","possible_hits":"0",},
{"lineNum":"   96","line":"\tfi"},
{"lineNum":"   97","line":"}"},
{"lineNum":"   98","line":""},
{"lineNum":"   99","line":"function optional() {"},
{"lineNum":"  100","line":"\tlocal args=(\"$@\")","class":"lineCov","hits":"3","order":"165","possible_hits":"0",},
{"lineNum":"  101","line":""},
{"lineNum":"  102","line":"\t# remove all flags from call"},
{"lineNum":"  103","line":"\tlocal del=(\"--debug\" \"--exec\" \"--silent\" \"--optional\")","class":"lineCov","hits":"3","order":"166","possible_hits":"0",},
{"lineNum":"  104","line":"\tfor value in \"${del[@]}\"; do","class":"lineCov","hits":"12","order":"167","possible_hits":"0",},
{"lineNum":"  105","line":"\t\tfor i in \"${!args[@]}\"; do","class":"lineCov","hits":"41","order":"168","possible_hits":"0",},
{"lineNum":"  106","line":"\t\t\tif [[ ${args[i]} == \"${value}\" ]]; then unset \'args[i]\'; fi","class":"lineCov","hits":"42","order":"169","possible_hits":"0",},
{"lineNum":"  107","line":"\t\tdone"},
{"lineNum":"  108","line":"\tdone"},
{"lineNum":"  109","line":""},
{"lineNum":"  110","line":"\t# inject default parameters"},
{"lineNum":"  111","line":"\tif [ \"${#args[@]}\" == \"2\" ]; then","class":"lineCov","hits":"3","order":"170","possible_hits":"0",},
{"lineNum":"  112","line":"\t\targs+=(\"No details. Please google it.\" \"--version\")","class":"lineCov","hits":"1","order":"183","possible_hits":"0",},
{"lineNum":"  113","line":"\telif [ \"${#args[@]}\" == \"3\" ]; then","class":"lineCov","hits":"2","order":"171","possible_hits":"0",},
{"lineNum":"  114","line":"\t\targs+=(\"--version\")","class":"lineNoCov","hits":"0","possible_hits":"0",},
{"lineNum":"  115","line":"\tfi"},
{"lineNum":"  116","line":""},
{"lineNum":"  117","line":"\t# recover flags"},
{"lineNum":"  118","line":"\tif [ \"$(isExec \"$@\")\" == \"true\" ]; then args+=(\"--exec\"); fi","class":"lineCov","hits":"6","order":"172","possible_hits":"0",},
{"lineNum":"  119","line":"\tif [ \"$(isSilent \"$@\")\" == \"true\" ]; then args+=(\"--silent\"); fi","class":"lineCov","hits":"6","order":"173","possible_hits":"0",},
{"lineNum":"  120","line":"\tif [ \"$(isDebug \"$@\")\" == \"true\" ]; then args+=(\"--debug\"); fi","class":"lineCov","hits":"7","order":"176","possible_hits":"0",},
{"lineNum":"  121","line":"\targs+=(\"--optional\")","class":"lineCov","hits":"3","order":"179","possible_hits":"0",},
{"lineNum":"  122","line":""},
{"lineNum":"  123","line":"\t# we should expand any number of input arguments to required 4 + extra flags"},
{"lineNum":"  124","line":"\tdependency \"${args[@]}\"","class":"lineCov","hits":"3","order":"180","possible_hits":"0",},
{"lineNum":"  125","line":"}"},
{"lineNum":"  126","line":""},
{"lineNum":"  127","line":"# This is the writing style presented by ShellSpec, which is short but unfamiliar."},
{"lineNum":"  128","line":"# Note that it returns the current exit status (could be non-zero)."},
{"lineNum":"  129","line":"# DO NOT allow execution of code bellow those line in shellspec tests"},
{"lineNum":"  130","line":"${__SOURCED__:+return}","class":"lineCov","hits":"1","order":"126","possible_hits":"0",},
{"lineNum":"  131","line":""},
{"lineNum":"  132","line":"logger dependencies \"$@\" # register own debug tag & logger functions","class":"lineNoCov","hits":"0","possible_hits":"0",},
{"lineNum":"  133","line":""},
{"lineNum":"  134","line":"# Tests:"},
{"lineNum":"  135","line":"#dependency bash \"5.0.18(1)-release\" \"brew install bash\" \"--version\""},
{"lineNum":"  136","line":"#dependency bash \"5.0.[0-9]{2}(1)-release\" \"brew install bash\" \"--version\""},
{"lineNum":"  137","line":"#dependency bash \"5.0.*(1)-release\" \"brew install bash\" \"--version\""},
{"lineNum":"  138","line":"#dependency bash \"5.*.*(1)-release\" \"brew install bash\" \"--version\""},
{"lineNum":"  139","line":"#dependency bash \"5.*.*\" \"brew install bash\" \"--version\" --debug # print debug info"},
{"lineNum":"  140","line":"#dependency bash \"5.*.*\" \"brew install bash\" \"--version\" 0 # ignore $5 parameter"},
{"lineNum":"  141","line":"#dependency git \"2.*.*\" \"brew install git\" \"--version\""},
{"lineNum":"  142","line":"#dependency bazelisk \"4.*.*\" \"brew install bazel\" \"--version\""},
{"lineNum":"  143","line":"#dependency yq \"4.13.2\" \"brew install yq\" \"-V\""},
{"lineNum":"  144","line":"#dependency jq \"1.6\" \"brew install jq\""},
{"lineNum":"  145","line":"#dependency bash \"[45].*.*\" \"brew install bash\" # allow 4.xx and 5.xx versions"},
{"lineNum":"  146","line":"#dependency go \"1.17.*\" \"brew install go\" \"version\""},
{"lineNum":"  147","line":"#dependency buildozer \"redacted\" \"go get github.com/bazelbuild/buildtools/buildozer\" \"-version\" 1"},
{"lineNum":"  148","line":"#dependency buildozer \"redacted\" \"go get github.com/bazelbuild/buildtools/buildozer\""},
{"lineNum":"  149","line":"#dependency go \"1.17.*\" \"brew install go && (echo \'export GOPATH=\\$HOME/go; export PATH=\\$GOPATH/bin:\\$PATH;\' >> ~/.zshrc)\" \"version\""},
{"lineNum":"  150","line":"#dependency go \"2.17.*\" \"echo \'export GOPATH=\\$HOME/go; export PATH=\\$GOPATH/bin:\\$PATH;\'\" \"version\" --exec"},
{"lineNum":"  151","line":"#dependency go \"2.17.*\" \"echo \'export GOPATH=\\$HOME/go; export PATH=\\$GOPATH/bin:\\$PATH;\' >> ~/.zshrc\" \"version\" --debug"},
{"lineNum":"  152","line":""},
{"lineNum":"  153","line":"# ref:"},
{"lineNum":"  154","line":"#  https://docs.gradle.org/current/userguide/single_versions.html"},
{"lineNum":"  155","line":"#  https://github.com/qzb/sh-semver"},
{"lineNum":"  156","line":"#  https://stackoverflow.com/questions/4023830/how-to-compare-two-strings-in-dot-separated-version-format-in-bash"},
]};
var percent_low = 25;var percent_high = 75;
var header = { "command" : "shellspec spec", "date" : "2023-10-06 23:02:19", "instrumented" : 64, "covered" : 62,};
var merged_data = [];
