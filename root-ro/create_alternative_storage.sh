#!/bin/sh

mkdir -p /.var/db
mv /var/db/pkg /.var/db/
chflags -R noschg /var
rm -rf /var
