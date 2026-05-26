#!/bin/bash
say() {
        echo "$1" | iconv -f utf-8 -t cp1251 2>/dev/null || echo "$1"
}
hostnamectl hostname HQ-CLI.au-team.irpo
