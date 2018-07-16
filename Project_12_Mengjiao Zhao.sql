/*1.*/

--CORRECT
CREATE OR REPLACE VIEW CURRENT_SHAREHOLDER_SHARES 
AS
SELECT 
   nvl(buy.buyer_id, sell.seller_id) AS shareholder_id,
   sh.type,
   nvl(buy.stock_id, sell.stock_id) AS  stock_id, 
   CASE nvl(buy.buyer_id, sell.seller_id)
      WHEN c.company_id THEN NULL
      ELSE nvl(buy.shares,0) - nvl(sell.shares,0)
   END AS shares
FROM (SELECT 
        t_sell.seller_id,
        t_sell.stock_id,
      sum(t_sell.shares) AS shares
      FROM trade t_sell
      WHERE t_sell.seller_id IS NOT NULL
      GROUP BY t_sell.seller_id, t_sell.stock_id) sell
  FULL OUTER JOIN
     (SELECT 
        t_buy.buyer_id,  
        t_buy.stock_id,
        sum(t_buy.shares) AS shares
      FROM trade t_buy
      WHERE t_buy.buyer_id IS NOT NULL
      GROUP BY t_buy.buyer_id, t_buy.stock_id) buy
   ON sell.seller_id = buy.buyer_id
   AND sell.stock_id = buy.stock_id
  JOIN shareholder sh
    ON sh.shareholder_id = nvl(buy.buyer_id, sell.seller_id)
  JOIN company c
    ON c.stock_id = nvl(buy.stock_id, sell.stock_id)
WHERE nvl(buy.shares,0) - nvl(sell.shares,0) != 0
ORDER BY 1,3;
/*Consistent Gets:
The number of consistent gets represents how many times Oracle must read the
blocks in memory (logical reads) in order to process the query.  It is the
best representation of how much work the database engine is doing.*/
/*
The first query runs more efficiently since the value of consistant gets is lower.
The consistant gets of first query=20
The consistant gets of second query=1156*/

/*2.*/

--CORRECT
CREATE OR REPLACE VIEW CURRENT_STOCKS_STATS 
AS
SELECT
  co.stock_id,
  si.authorized current_authorized,
  SUM(DECODE(t.seller_id,co.company_id,t.shares)) 
    -NVL(SUM(CASE WHEN t.buyer_id = co.company_id 
             THEN t.shares END),0) AS total_outstanding
FROM company co
  INNER JOIN shares_authorized si
     ON si.stock_id = co.stock_id
    AND si.time_end IS NULL
  LEFT OUTER JOIN trade t
      ON t.stock_id = co.stock_id
GROUP BY co.stock_id, si.authorized
ORDER BY stock_id
;
/*The second query runs more efficiently since the value of consistant gets is lower.
The consistant gets of first query=92
The consistant gets of second query=16*/

/*3.*/
--CORRECT
SELECT c.name,current_authorized,total_outstanding, Round((total_outstanding/current_authorized*100),2) AS Percentage_AO FROM company c
JOIN
CURRENT_STOCKS_STATS
ON c.stock_ID=CURRENT_STOCKS_STATS.stock_id;


/*4*/
--CORRECT
SELECT d.first_name,d.last_name, c.NAME,shares,
Round((shares/total_outstanding*100),2) AS P_Holder_Share_Outstanding,
Round((shares/current_authorized*100),2) AS P_Holder_Share_Authorized
From
direct_holder d
JOIN Current_shareholder_shares C_s_s
ON d.DIRECT_HOLDER_ID=C_s_s.SHAREHOLDER_ID
JOIN company c
ON C_s_s.STOCK_ID=c.STOCK_ID
JOIN CURRENT_STOCKS_STATS 
ON CURRENT_STOCKS_STATS.stock_id=C_s_s.STOCK_ID
ORDER BY d.last_name,d.first_name,c.NAME;

/*5*/
--CORRECT
SELECT c.name AS Name_holder, com.name Name_company,shares,
Round((shares/total_outstanding*100),2) AS P_Holder_Share_Outstanding,
Round((shares/current_authorized*100),2) AS P_Holder_Share_Authorized
FROM  Current_shareholder_shares c_s_s
JOIN company c
ON c_s_s.shareholder_id= c.company_id  /*Get the shareholder company name*/
JOIN company com
ON c_s_s.stock_id=com.stock_id  /*Get the company which is inversted's name*/
JOIN CURRENT_STOCKS_STATS 
ON CURRENT_STOCKS_STATS.stock_id=c_s_s.STOCK_ID
WHERE type='Company' AND c.name != com.name
ORDER BY Name_holder,Name_company;

/*6*/
--INCORRECT. TRADE 28 IS LISTED TWICE, BECAUSE YOU DIDNT ACCOUNT FOR THE FACT
--THAT THE STOCK IS LISTED ON SEVERAL EXCHANGES. YOU NEED AN ADDITIONAL JOIN CONDITION
--IN YOUR SECOND TO LAST JOIN.
SELECT t.trade_id,s_l.stock_symbol,c.name AS company_name,s_e.SYMBOL AS stock_exchange_symbol,t.SHARES,t.PRICE_TOTAL,curr.symbol
FROM trade t
JOIN stock_exchange s_e
ON s_e.STOCK_EX_ID=t.STOCK_EX_ID
JOIN Company c
ON c.STOCK_ID=t.stock_ID
JOIN stock_listing s_l
ON s_l.STOCK_ID=t.stock_ID AND s_l.STOCK_ex_ID=t.stock_ex_ID
JOIN currency curr
on curr.CURRENCY_ID=s_e.CURRENCY_ID
WHERE shares>50000;

/*7*/
--CORRECT
SELECT s_e.name,s_l.STOCK_SYMBOL,max(To_Char(t.transaction_time,'YYYY-MM-DD HH24:MM:SS'))
FROM stock_listing s_l
left JOIN stock_exchange s_e
ON s_l.stock_ex_id=s_e.stock_ex_id
left JOIN trade t
ON t.stock_id=s_l.stock_id
group by s_e.name,s_l.STOCK_SYMBOL
ORDER by  s_e.name;
/*8*/
/*SELECT t.trade_id,c.name,max(c_s_s.shares)
FROM trade t
right JOIN company c
ON t.STOCK_ID=c.STOCK_ID
left JOIN Current_shareholder_shares c_s_s
ON c_s_s.STOCK_ID=t.stock_id
JOIN stock_exchange s_e
ON t.stock_ex_id=s_e.stock_ex_id
GROUP BY t.trade_id,c.name
ORDER BY t.trade_id ASC;*/

--CORRECT
SELECT t.trade_id,c.name,t.shares
FROM trade t
JOIN company c
ON t.STOCK_ID=c.STOCK_ID
JOIN stock_exchange s_e
ON t.stock_ex_id=s_e.stock_ex_id
WHERE t.shares=(SELECT max(shares) FROM trade WHERE stock_ex_id IS NOT NULL);


/*9*/
--CORRECT, BUT YOUVE OVERCOMPLICATED IT. DONT NEED A SEQUENCE. QUERY THE MAX
--SHAREHOLDER ID FIRST, AND THEN YOU CAN HARDCODE IT WITH TWO INSERTS.
SELECT MAX(shareholder_id)
FROM Shareholder;

DROP SEQUENCE shareholder_id_seq;

CREATE SEQUENCE shareholder_id_seq
   INCREMENT BY 1
   START WITH 25;
   
INSERT INTO Shareholder
  (shareholder_id,type)
  VALUES (shareholder_id_seq.NEXTVAL,'Direct_Holder');
SELECT * FROM Shareholder; 

 /*
Rollback;
DELETE FROM Shareholder
WHERE shareholder_id=40;
ALTER TABLE company DROP CONSTRAINT CO_SHAREHOLDER_FK;*/
   
INSERT INTO direct_holder
  (direct_holder_id,
  first_name,last_name)
  VALUES ((SELECT max(shareholder_id) FROM shareholder), 'Jeff','Adams');
  
SELECT * FROM direct_holder;

/*DELETE FROM direct_holder
WHERE direct_holder_id=20; */
 
/*10*/
--CORRECT, SAME AS ABOVE.
INSERT INTO Shareholder
  (shareholder_id,type)
  VALUES (shareholder_id_seq.NEXTVAL,'Company');
SELECT * FROM Shareholder; 

INSERT INTO company
(company_id,name, place_id)
 VALUES ((SELECT max(shareholder_id) FROM shareholder), 'Makoto Investing',
 (SELECT place_id FROM place WHERE city='Tokyo' AND country='Japan'));
 
ALTER TABLE company DROP CONSTRAINT SI_STOCK_FK;
/*
SELECT * FROM company;
DELETE FROM company
WHERE company_id=26; 
*/

/*11*/
--CORRECT
SELECT MAX(stock_id)
FROM stock_listing;

DROP SEQUENCE stock_id_seq;

CREATE SEQUENCE stock_id_seq
   INCREMENT BY 1
   START WITH 8;
   
UPDATE company c
  SET c.stock_id = stock_id_seq.NEXTVAL,
  c.starting_price = 50,
  c.currency_id= (SELECT currency_id FROM currency where name='Yen')
WHERE c.name='Makoto Investing';

Insert into shares_authorized 
(stock_id,time_start,time_end,authorized)
VALUES ((select stock_id from company WHERE name='Makoto Investing'),(SELECT TRUNC(SYSDATE,'DD') FROM dual),NULL,100000 );

SELECT * FROM shares_authorized;
/*
DELETE FROM company
WHERE company_id=26; */

/*12*/
--CORRECT
INSERT INTO STOCK_LISTING 
(STOCK_ID,STOCK_EX_ID,STOCK_SYMBOL )
VALUES ((SELECT stock_id from company WHERE name='Makoto Investing'),
(SELECT stock_ex_id FROM STOCK_EXCHANGE WHERE name='Tokyo Stock Exchange'),
'Makoto');
 
 INSERT INTO STOCK_PRICE
 (stock_id,stock_ex_id,price,time_start,time_end)
 VALUES((SELECT stock_id from company WHERE name='Makoto Investing'),
 (SELECT stock_ex_id FROM STOCK_EXCHANGE WHERE name='Tokyo Stock Exchange'),50,
 (SELECT TRUNC(SYSDATE,'DD') FROM dual),NULL
 );

