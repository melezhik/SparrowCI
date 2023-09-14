mkdir ~/rakudo && cd $_
curl -LJO https://rakudo.org/latest/rakudo/src
tar -xvzf rakudo-*.tar.gz
cd rakudo-*

perl Configure.pl --backend=moar --gen-moar
make
make install
