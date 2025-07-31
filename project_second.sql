
---ex 1
select*
from Sales.Orders
select*
from Sales.OrderLines


with yearInc
as
(select YEAR(n.OrderDate) as "year", SUM(p.UnitPrice*p.PickedQuantity) as IncomePerYear,
count(distinct MONTH(n.OrderDate)) as NumberOfDistinctMonth,
ROUND(CAST(SUM(p.UnitPrice * p.PickedQuantity) / NULLIF(COUNT(DISTINCT MONTH(n.OrderDate)), 0) * 12 AS DECIMAL(18,2)), 2) AS YearlyLinearIncome
from Sales.Orders n join Sales.OrderLines p
on n.OrderID=p.OrderID
group by YEAR(n.OrderDate))
select "year",IncomePerYear, NumberOfDistinctMonth, YearlyLinearIncome,
round(
    cast(
        (YearlyLinearIncome - LAG(YearlyLinearIncome) over (order by "year")) 
        / NULLIF(LAG(YearlyLinearIncome) OVER (ORDER BY "year"), 0) * 100 
    as decimal(18,2)), 
2) AS GrowthRate
from yearInc

--- ex 2

with qtr
as
(select YEAR(o.OrderDate) as "Year", DATEPART(QUARTER, o.OrderDate) as TheQuarter,
c.CustomerName as CustomerName, SUM(l.UnitPrice*l.PickedQuantity) as IncomePerYear,
RANK() over (partition by YEAR(o.OrderDate),DATEPART(QUARTER, o.OrderDate) order by SUM(l.UnitPrice*l.PickedQuantity) desc) as DNR
from Sales.Orders o join Sales.Customers c
on o.CustomerID= c.CustomerID
join Sales.OrderLines l
on o.OrderID=l.OrderID
group by YEAR(o.OrderDate), DATEPART(QUARTER, o.OrderDate),c.CustomerName, c.CustomerID)
select*
from qtr 
where DNR <=5

--- ex 3

select  top 10 w.StockItemID, w.StockItemName, SUM(s.ExtendedPrice-s.TaxAmount) as TotalProfit
from Warehouse.StockItems w join Sales.InvoiceLines s
on w.StockItemID=s.StockItemID
group by w.StockItemID, w.StockItemName
order by SUM(s.ExtendedPrice-s.TaxAmount) desc

---ex 4

select ROW_NUMBER() over (order by (RecommendedRetailPrice-UnitPrice) desc) as RN , StockItemID, StockItemName, UnitPrice, 
RecommendedRetailPrice, SUM(RecommendedRetailPrice-UnitPrice) as NominalProductProfit,
DENSE_RANK() over (order by (RecommendedRetailPrice-UnitPrice) desc) as DNR
from Warehouse.StockItems
group by StockItemID, StockItemName, UnitPrice, RecommendedRetailPrice


--- ex 5

select CONCAT(p.SupplierID, '-' , p.SupplierName) as SupplierDetails, 
STRING_AGG(concat(w.stockitemid  ,' ', w.StockItemName), ' /,') as ProductDetails
from Purchasing.Suppliers p join Warehouse.StockItems w
on p.SupplierID=w.SupplierID
group by p.SupplierID, p.SupplierName


---ex6

select top 5 Cu.CustomerID, Cit.CityName, Countr.CountryName, Countr.Region,
format(SUM( InLi.ExtendedPrice), 'N2','en-EU') as TotalExtendedPrice
from Sales.InvoiceLines InLi join Sales.Invoices Inv
on InLi.InvoiceID=Inv.InvoiceID
join Sales.Customers Cu
on Inv.CustomerID=Cu.CustomerID
join Application.Cities Cit
on Cu.DeliveryCityID=Cit.CityID
join Application.StateProvinces Prov
on Cit.StateProvinceID=Prov.StateProvinceID
join Application.Countries Countr
on Prov.CountryID=Countr.CountryID
group by Cu.CustomerID, Cit.CityName, Countr.CountryName, Countr.Region
order by SUM(InLi.ExtendedPrice) desc


---ex 7

with cte
as
(select YEAR(o.OrderDate) as OrderYear, MONTH(o.OrderDate) as OrderMonth, 
       SUM(OL.PickedQuantity*OL.UnitPrice) as MonthlyTotal
from Sales.Orders O join Sales.OrderLines OL
on o.OrderID=OL.OrderID
group by rollup (YEAR(o.OrderDate),MONTH(o.OrderDate))),
Monthly
as
(select OrderYear, CAST(OrderMonth AS VARCHAR) AS OrderMonth, MonthlyTotal,
        SUM(MonthlyTotal) over (partition by OrderYear order by CAST(OrderMonth as int)
	    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as CumulativeTotal,
	    CAST(OrderMonth AS INT) AS SortMonth
from cte
where OrderMonth is not null),
gtotal
as
(select OrderYear, 'Grand Total' as OrderMonth,
        sum(MonthlyTotal) as MonthlyTotal,
		SUM(MonthlyTotal) as CumulativeTotal,
		13 as SortMonth
   from cte
     where OrderMonth IS NOT NULL
    group by OrderYear),
Combina
as 
(select*
 from Monthly
    union all
 select*
  from gtotal)
  select OrderYear, OrderMonth, Format(MonthlyTotal, 'N2','en-US'), format(CumulativeTotal, 'N2', 'en-US')
  from Combina
  order by OrderYear, SortMonth


--- ex 8 


with tbe
as
(select YEAR(OrderDate) as OrderYear, MONTH(OrderDate) as OrderMonth,
COUNT(OrderDate) as OrderCount
from Sales.Orders
group by  YEAR(OrderDate), MONTH(OrderDate))
select OrderMonth, 
       ISNULL([2013], 0) AS [2013], 
       ISNULL([2014], 0) AS [2014], 
       ISNULL([2015], 0) AS [2015], 
       ISNULL([2016], 0) AS [2016]
from tbe
pivot (sum(OrderCount)
        for OrderYear  in ([2013],[2014],[2015],[2016])) as p

---- ex 9



;WITH cte as (
    select 
        c.CustomerID,
        c.CustomerName,
        o.OrderDate,
		MAX(o.OrderDate) over (partition by c.CustomerID) as LastOrderDate,
        LAG(o.OrderDate, 1) over (partition by c.CustomerID order by o.OrderDate) as PreviousOrderDate
    from Sales.Orders o
    join Sales.Customers c on o.CustomerID = c.CustomerID),
nast as (
    select
        CustomerID,
        CustomerName,
        OrderDate,
        PreviousOrderDate,
        DATEDIFF(DAY, LastOrderDate,'2016-05-31' ) as DaysSinceLastOrder,
        AVG(CASE when PreviousOrderDate IS NOT NULL 
                 then DATEDIFF(DAY, PreviousOrderDate, OrderDate) 
            END)
			OVER (PARTITION BY CustomerID) AS AvgDaysBetweenOrders
    from cte)
select
    CustomerID,
    CustomerName,
    OrderDate,
    PreviousOrderDate,
    DaysSinceLastOrder,
    AvgDaysBetweenOrders,
    CASE
        WHEN DaysSinceLastOrder > 2 * AvgDaysBetweenOrders 
        THEN 'Potential Churn'
        ELSE 'Active'
    END AS CustomerStatus
from nast
order by CustomerID, OrderDate;


------------------ ex 10


;with lui
as
(select distinct case 
        when CustomerName like 'Tailspin%' then 'Tailspin Toys'
        when CustomerName like 'Wingtip%' then 'Wingtip Electronics'
        else CustomerName
    end as CustomerName,
    b.CustomerCategoryName as CustomerCategoryName,
	a.CustomerCategoryID as CustomerCategoryID
from Sales.Customers a join Sales.CustomerCategories b
on a.CustomerCategoryID=b.CustomerCategoryID),
chaki
as
(select CustomerCategoryName, 
       count (CustomerCategoryID) as CustomerCOUNT
from lui
group by CustomerCategoryName),
ccn
as
(select CustomerCategoryName, CustomerCOUNT,
       SUM(CustomerCOUNT) over () as TotalCustomers,
	   Round((CustomerCOUNT * 100.0) / SUM(CustomerCOUNT) OVER (), 2) AS DistributionFactor
from chaki)
select CustomerCategoryName, CustomerCOUNT, TotalCustomers, concat( format(DistributionFactor, '0.##'), '%') as DistributionFactor
from ccn






