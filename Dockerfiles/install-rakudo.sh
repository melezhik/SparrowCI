mkdir ~/rakudo && cd $_
curl -LJO https://rakudo.org/dl/rakudo/rakudo-$1.tar.gz
tar -xvzf rakudo-*.tar.gz
cd rakudo-*

perl Configure.pl --backend=moar --gen-moar
make
make install
