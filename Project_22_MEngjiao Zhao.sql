SELECT * FROM SHareholder;
SELECT * FROM direct_holder;
SELECT * FROM company;
SELECT * FROM Current_shareholder_shares;
SELECT * FROM trade;
SELECT * FROM stock_exchange;
SELECT * FROM stock_price;
SELECT * FROM stock_listing;
SELECT * FROM place;
SELECT * FROM Current_stocks_stats;
/*13*/

  SELECT MAX(shareholder_id)
FROM Shareholder;

DROP SEQUENCE shareholder_id_seq;

CREATE SEQUENCE shareholder_id_seq
   INCREMENT BY 1
   START WITH 30;
  
CREATE OR REPLACE PROCEDURE INSERT_DIRECT_HOLDER (
p_first_name IN direct_holder.first_name%TYPE,
p_last_name IN direct_holder.last_name%TYPE
)
AS
l_direct_holder_id NUMBER(6,2) NULL;
BEGIN  
     l_direct_holder_id := shareholder_id_seq.NEXTVAL;
  INSERT INTO Shareholder
  (shareholder_id,type)
  VALUES (l_direct_holder_id,'Direct_Holder');
  
  INSERT INTO direct_holder (direct_holder_id, first_name, last_name)
  VALUES (l_direct_holder_id, p_first_name, p_last_name);
  
END;
/
show errors procedure insert_broker;
EXEC insert_direct_holder('Joe','Duff');

SELECT * FROM Shareholder; 
SELECT * FROM direct_holder;

DELETE FROM direct_holder
WHERE FIRST_NAME='Joe' AND LAST_NAME='Duff';

/*14*/  
CREATE OR REPLACE PROCEDURE INSERT_COMPANY (
p_company_name IN company.name%TYPE,
p_city IN place.city%TYPE,
p_country IN PLACE.COUNTRY%TYPE
)
AS
l_share_holder_id NUMBER(6,2) NULL;
BEGIN
  /*IF l_direct_holder_id IS NULL THEN
     l_direct_holder_id := 1;
  ELSE
     l_direct_holder_id := shareholder_id_seq.NEXTVAL;
  END IF; */
       l_share_holder_id := shareholder_id_seq.NEXTVAL;
  INSERT INTO Shareholder
  (shareholder_id,type)
  VALUES (l_share_holder_id,'Company');
  
  INSERT INTO company
  (company_id,name,place_ID,STOCK_ID,STARTING_PRICE,CURRENCY_ID)
  VALUES (l_share_holder_id,p_company_name,
  (SELECT place_id FROM place WHERE city=p_city AND country=p_country),NULL,NULL,NULL); 
END;
/
EXEC INSERT_COMPANY( 'Morgan Stanley','Tokyo','Japan');

/*15*/
 SELECT MAX(stock_id)
FROM stock_listing;

DROP SEQUENCE stock_id_seq;

CREATE SEQUENCE stock_id_seq
   INCREMENT BY 1
   START WITH 10;
CREATE OR REPLACE PROCEDURE DECLARE_STOCK(
p_company_name IN company.name%type,
p_authorized IN SHARES_AUTHORIZED.AUTHORIZED%type,
p_starting_price IN company.starting_price%type,
p_name IN currency.name%type)
AS
l_stock_id NUMBER(6,2) NULL;
BEGIN
SELECT stock_id
  INTO l_stock_id
  FROM company 
  WHERE company.name=p_company_name;
  
IF l_stock_id IS NULL THEN
 UPDATE company 
   SET company.stock_id= stock_id_seq.NEXTVAL,
   company.starting_price=p_starting_price,
   company.currency_id=(SELECT currency_id FROM currency where currency.name=p_name)
  WHERE company.name=p_company_name;
INSERT INTO shares_authorized (stock_id, time_start, time_end,authorized)
VALUES ((SELECT stock_id FROM company WHERE company.name=p_company_name), 
  (SELECT SYSDATE FROM dual), 
  NULL,
  p_authorized); 
END IF;

END;
/
EXEC DECLARE_STOCK('RBC',1000,100,'Yen');
EXEC DECLARE_STOCK('IBM',1000,100,'Yen');

/*16*/
CREATE OR REPLACE PROCEDURE LIST_STOCK(
p_stock_id IN stock_listing.stock_id%type,
p_stock_ex_id IN stock_listing.stock_ex_id%type,
p_stock_symbol IN STOCK_LISTING.STOCK_SYMBOL%type)
AS
l_stock_id NUMBER(6,2) NULL;
l_stock_ex_id NUMBER(6,2) NULL;
l_starting_rate NUMBER(6,2) NULL;
l_exchange_rate NUMBER(6,2) NULL;
BEGIN

INSERT INTO stock_listing (stock_id,stock_ex_id,stock_symbol)
VALUES (p_stock_id,p_stock_ex_id,p_stock_symbol);

SELECT starting_price INTO l_starting_rate FROM Company WHERE stock_id=p_stock_id;
SELECT exchange_rate INTO l_exchange_rate FROM conversion WHERE 
((from_currency_id=(SELECT currency_id FROM company WHERE stock_id=p_stock_id)) AND (to_currency_id=(SELECT currency_id FROM stock_exchange WHere stock_ex_id=p_stock_ex_id)));

INSERT INTO STOCK_PRICE
 (stock_id,stock_ex_id,price,time_start,time_end)
 VALUES(p_stock_id,
 p_stock_ex_id,Round((l_exchange_rate*l_starting_rate),2),
 (SELECT SYSDATE FROM dual),NULL);
 /*INSERT INTO STOCK_PRICE
 (stock_id,stock_ex_id,price,time_start)
 VALUES(p_stock_id,
 p_stock_ex_id,(l_exchange_rate*l_starting_rate),
 (SELECT SYSDATE FROM dual));*/

END;
/
EXEC  LIST_STOCK (7,3,'LALALA');

/*17*/
 SELECT MAX(trade_id)
FROM trade;

DROP SEQUENCE trade_id_seq;

CREATE SEQUENCE trade_id_seq
   INCREMENT BY 1
   START WITH 60;
CREATE OR REPLACE PROCEDURE SPLIT_STOCK(
p_stock_id IN stock_listing.stock_id%type,
p_split_factor IN NUMBER)
AS
l_current_authorized NUMBER(14) NULL;
l_total_outstanding NUMBER(14) NULL;

BEGIN

 SELECT current_authorized,total_outstanding INTO l_current_authorized,l_total_outstanding FROM current_stocks_stats WHERE stock_id=p_stock_id;

IF (l_total_outstanding<l_current_authorized) AND (p_split_factor>1) THEN
INSERT INTO trade
 (trade_id,stock_id,TRANSACTION_TIME,shares,buyer_id,seller_id)
  SELECT 
    trade_id_seq.NEXTVAL,
    p_stock_id,
    SYSDATE,
    css.shares*(p_split_factor-1),
    css.shareholder_id,
    css.stock_id
  FROM current_shareholder_shares css
  WHERE css.stock_id = p_stock_id
  AND css.shares IS NOT NULL;
  
ELSE
    RAISE_APPLICATION_ERROR(-20000, 'Total shares outstanding cannot exceed the authorized amount or split_factor is smaller than 1!');
END IF;
END;
/
EXEC SPLIT_STOCK(2,2);

/*18*/
 SELECT MAX(trade_id)
FROM trade;

DROP SEQUENCE trade_id_seq;

CREATE SEQUENCE trade_id_seq
   INCREMENT BY 1
   START WITH 68;
CREATE OR REPLACE PROCEDURE REVERSE_Split(
p_stock_id IN stock_listing.stock_id%type,
p_merge_factor IN NUMBER)
AS
l_current_authorized NUMBER(14) NULL;
l_total_outstanding NUMBER(14) NULL;

BEGIN

SELECT current_authorized,total_outstanding INTO l_current_authorized,l_total_outstanding FROM current_stocks_stats WHERE stock_id=p_stock_id;

IF (p_merge_factor>0 AND p_merge_factor<1) THEN

INSERT INTO trade
 (trade_id,stock_id,TRANSACTION_TIME,shares,buyer_id,seller_id)
  SELECT 
    trade_id_seq.NEXTVAL,
    p_stock_id,
    SYSDATE,
    css.shares*(1-p_merge_factor),
    css.stock_id,
    css.shareholder_id
  FROM current_shareholder_shares css
  WHERE css.stock_id = p_stock_id
  AND css.shares IS NOT NULL;
 
ELSE
     RAISE_APPLICATION_ERROR(-20000, 'Merge factor should be between 0 to 1!');
  END IF;
END;
/


EXEC reverse_split(2,0.5);

/*19*/

WITH trade_US  AS
    (SELECT trade_id, stock_id,(price_total *exchange_rate) AS US_price,trade.STOCK_EX_ID,exchange_rate
    FROM trade,conversion
    WHERE (exchange_rate= (SELECT exchange_rate FROM conversion WHERE 
    (from_currency_id=(SELECT currency_id FROM stock_exchange s_e WHERE s_e.STOCK_EX_ID=trade.stock_ex_id) AND 
    to_currency_id= 1)
    )
    )
    )  
SELECT DISTINCT t_US.trade_id, t_US.stock_id, US_price
FROM trade_US t_US
WHERE US_price=(SELECT max(US_price) FROM trade_US WHERE stock_ex_id IS NOT NULL);

/*20*/
With Trade_volume AS
(
SELECT stock_id,sum(t_sell.shares) AS shares
      FROM trade t_sell
      WHERE t_sell.seller_id IS NOT NULL
      GROUP BY t_sell.stock_id
      )
SELECT name, shares
FROM company c
JOIN Trade_volume
ON c.stock_id = Trade_volume.stock_id 
WHERE shares=(SELECT max(shares) FROM Trade_volume);
/*21*/
With Trade_volume AS
(
SELECT stock_id,stock_ex_id,sum(t_sell.shares) AS shares
      FROM trade t_sell
      WHERE t_sell.stock_ex_id IS NOT NULL
      GROUP BY t_sell.stock_ex_id, t_sell.stock_id
      )
SELECT s_e.name,stock_symbol, tv.shares
FROM stock_listing
JOIN Trade_volume tv
ON tv.stock_ex_id=stock_listing.stock_ex_id 
AND  tv.stock_id=stock_listing.stock_id 
JOIN stock_exchange s_e
ON s_e.stock_ex_id=stock_listing.stock_ex_id
WHERE shares = (SELECT MAX(shares) FROM Trade_volume tv_sub WHERE tv_sub.stock_ex_id = tv.stock_ex_id )
ORDER BY s_e.name,stock_symbol;
/*22*/
SELECT c.name, t.stock_id FROM company c 
JOIN trade t
ON c.stock_id=t.stock_id 
where t.STOCK_EX_ID=(SELECT s_e.stock_ex_id FROM
stock_exchange s_e 
WHERE name='New York Stock Exchange');