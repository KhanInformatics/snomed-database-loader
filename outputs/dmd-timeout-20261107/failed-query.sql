SELECT
    (SELECT COUNT(*) FROM #ampp_price s LEFT JOIN dbo.ampp p ON p.appid = s.appid WHERE p.appid IS NULL) +
    (SELECT COUNT(*) FROM #ampp_price s WHERE NOT EXISTS (
        SELECT 1 FROM dbo.lookup l WHERE l.type = 'PRICE_BASIS'
        AND TRY_CONVERT(BIGINT, l.cd) = TRY_CONVERT(BIGINT, s.price_basiscd)))
