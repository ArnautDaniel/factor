IN: temporary
USING: compiler kernel math sequences test ;

: sort-benchmark
    100000 [ drop 100000 random ] map natural-sort drop ;

[ ] [ sort-benchmark ] unit-test
