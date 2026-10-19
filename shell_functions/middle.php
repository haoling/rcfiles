<?php
#文字コード検出用 - あいうえお美乳眉幅
# vim: set ts=4 sw=4 sts=4 et ff=unix fenc=utf-8

if (! isset($argp) || ! is_array($argp)) $argp = array();
if (! isset($argu) || ! is_array($argu)) $argu = array();
for($i = 1; $i < $argc; $i++) {
    if(substr(trim($argv[$i]), 0, 2) == '--') {
        if (strpos($argv[$i], '=') !== false) {
            list($k, $v) = explode('=', $argv[$i], 2);
            $argv = array_merge(array_slice($argv, 0, $i), array($k, $v), array_slice($argv, $i + 1));
            $argc++;
            $i--;
            continue;
        }

        switch($name = substr(trim($argv[$i]), 2)) {
        default:
            //die('Unknown parameter: '.$argv[$i]."\n");
            if (isset($argv[$i+1]) && substr($argv[$i+1], 0 ,1) != '-') {
                if (is_array($argp[$name])) {
                    $argp[$name][] = $argv[$i+1];
                } else {
                    $argp[$name] = $argv[$i+1];
                }
                $i++;
            } else {
                $argp[$name] = true;
            }
            break;
        }
    } elseif(substr(trim($argv[$i]), 0, 1) == '-') {
        switch($name = substr(trim($argv[$i]), 1)) {
        case 'C':
            $argp['lines'] = $argv[$i+1];
            $i++;
            break;
        case 'A':
            $argp['after'] = $argv[$i+1];
            $i++;
            break;
        case 'B':
            $argp['before'] = $argv[$i+1];
            $i++;
            break;
        default:
            die('Unknown parameter: '.$argv[$i]."\n");
        }
    } else {
        $argu[] = $argv[$i];
    }
}
if (! array_key_exists('lines', $argp)) $argp['lines'] = 20;
if (! array_key_exists('before', $argp)) $argp['before'] = (int) floor(($argp['lines'] - 1) / 2);
if (! array_key_exists('after', $argp)) $argp['after'] = (int) ceil(($argp['lines'] - 1) / 2);

foreach ($argu as $arg) {
    $args = explode(':', $arg);
    if (count($args) == 1) {
        $file = $arg;
        $line = (int) round(`wc -l "${arg}"` / 2);
    } else {
        list($file, $line) = $args;
    }

    exec(sprintf('pygmentize -O encoding=utf-8 -O style=monokai -f terminal256 -g "%s"', $file), $data, $retval);
    if ($retval == 0) {
        array_walk($data, function(&$a){ $a .= "\n"; });
    } else {
        $data = file($file);
    }
    $data = array_slice($data, max(0, ($line - 1) - $argp['before']), min(count($data), $argp['before'] + $argp['after'] + 1), true);

    printf("%s\n", $arg);
    foreach ($data as $num => $row) {
        if ($num == $line - 1) echo "\x1b[30m\x1b[47m";
        printf("% 4d", $num+1);
        if ($num == $line - 1) echo "\x1b[39m\x1b[49m";
        printf("| %s", $row);
    }
    echo "\n";
}
