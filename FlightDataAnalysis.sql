--Q1 Find the busiest airport by the number of flights take off


SELECT TOP 1 WITH TIES
       a.AirportID,
       a.Name     AS Airport,
       a.Location AS City,
       COUNT(f.FlightID) AS Total_Departures
FROM dbo.Flights f
JOIN dbo.Airports a ON a.AirportID = f.Origin
GROUP BY a.AirportID, a.Name, a.Location
ORDER BY Total_Departures DESC;


--Q2 Total number of tickets sold per airline


SELECT al.AirlineID,
       al.Name AS Airline,
       COUNT(t.TicketID) AS Total_Tickets_Sold
FROM dbo.Airlines al
LEFT JOIN dbo.Flights f ON f.AirlineID = al.AirlineID
LEFT JOIN dbo.Tickets t ON t.FlightID  = f.FlightID
GROUP BY al.AirlineID, al.Name
ORDER BY Total_Tickets_Sold DESC, Airline;


--Q3 List all flights operated by ‘IndiGo’ with airport names (origin and destination)


SELECT f.FlightID,
       al.Name         AS Airline,
       orig.Name       AS Origin_Airport,
       dest.Name       AS Destination_Airport,
       f.DepartureTime,
       f.ArrivalTime
FROM dbo.Flights f
JOIN dbo.Airlines al  ON al.AirlineID   = f.AirlineID
JOIN dbo.Airports orig ON orig.AirportID = f.Origin
JOIN dbo.Airports dest ON dest.AirportID = f.Destination
WHERE al.Name = 'IndiGo'
ORDER BY f.DepartureTime;


--Q4 For each airport, show the top airline by number of flights departing from there


WITH airline_counts AS (
    SELECT a.AirportID,
           a.Name     AS Airport,
           a.Location AS City,
           al.Name    AS Airline,
           COUNT(*)   AS Flights_Departing
    FROM dbo.Flights f
    JOIN dbo.Airports a  ON a.AirportID  = f.Origin
    JOIN dbo.Airlines al ON al.AirlineID = f.AirlineID
    GROUP BY a.AirportID, a.Name, a.Location, al.AirlineID, al.Name
),
ranked AS (
    SELECT *,
           RANK() OVER (PARTITION BY AirportID ORDER BY Flights_Departing DESC) AS rnk
    FROM airline_counts
)
SELECT Airport, City, Airline, Flights_Departing
FROM ranked
WHERE rnk = 1
ORDER BY Airport, Airline;


--Q5 For each flight, show time taken in hours and categorize it as Short (<2h), Medium (2–5h), or Long (>5h)


SELECT f.FlightID,
       orig.Location AS Origin,
       dest.Location AS Destination,
       f.DepartureTime,
       f.ArrivalTime,
       CAST(DATEDIFF(MINUTE, f.DepartureTime, f.ArrivalTime) / 60.0 AS DECIMAL(5,2)) AS Duration_Hours,
       CASE
           WHEN DATEDIFF(MINUTE, f.DepartureTime, f.ArrivalTime) < 120 THEN 'Short'
           WHEN DATEDIFF(MINUTE, f.DepartureTime, f.ArrivalTime) <= 300 THEN 'Medium'
           ELSE 'Long'
       END AS Flight_Category
FROM dbo.Flights f
JOIN dbo.Airports orig ON orig.AirportID = f.Origin
JOIN dbo.Airports dest ON dest.AirportID = f.Destination
ORDER BY f.FlightID;



--Q6 Show each passenger's first and last flight dates and number of flights


SELECT p.PassengerID,
       p.Name,
       MIN(CAST(f.DepartureTime AS DATE)) AS First_Flight_Date,
       MAX(CAST(f.DepartureTime AS DATE)) AS Last_Flight_Date,
       COUNT(DISTINCT f.FlightID)         AS Number_of_Flights,
       COUNT(t.TicketID)                  AS Number_of_Tickets
FROM dbo.Passengers p
LEFT JOIN dbo.Tickets t ON t.PassengerID = p.PassengerID
LEFT JOIN dbo.Flights f ON f.FlightID    = t.FlightID
GROUP BY p.PassengerID, p.Name
ORDER BY p.PassengerID;



--Q7 Find flights with the highest price ticket sold for each route (origin -> destination)


WITH flight_max AS (
    SELECT f.FlightID,
           f.Origin,
           f.Destination,
           MAX(t.Price) AS Highest_Ticket_Price
    FROM dbo.Flights f
    JOIN dbo.Tickets t ON t.FlightID = f.FlightID
    GROUP BY f.FlightID, f.Origin, f.Destination
),
ranked AS (
    SELECT *,
           RANK() OVER (PARTITION BY Origin, Destination
                        ORDER BY Highest_Ticket_Price DESC) AS rnk
    FROM flight_max
)
SELECT r.FlightID,
       orig.Location AS Origin,
       dest.Location AS Destination,
       r.Highest_Ticket_Price
FROM ranked r
JOIN dbo.Airports orig ON orig.AirportID = r.Origin
JOIN dbo.Airports dest ON dest.AirportID = r.Destination
WHERE r.rnk = 1
ORDER BY r.Highest_Ticket_Price DESC, Origin;


--Q8 Find the highest spending passenger in each Frequent Flyer Status group


WITH passenger_spend AS (
    SELECT p.PassengerID,
           p.Name,
           p.FrequentFlyerStatus,
           COALESCE(SUM(t.Price), 0) AS Total_Spent,
           COUNT(t.TicketID)         AS Tickets_Bought
    FROM dbo.Passengers p
    LEFT JOIN dbo.Tickets t ON t.PassengerID = p.PassengerID
    GROUP BY p.PassengerID, p.Name, p.FrequentFlyerStatus
),
ranked AS (
    SELECT *,
           RANK() OVER (PARTITION BY FrequentFlyerStatus
                        ORDER BY Total_Spent DESC) AS rnk
    FROM passenger_spend
)
SELECT FrequentFlyerStatus,
       PassengerID,
       Name,
       Tickets_Bought,
       Total_Spent
FROM ranked
WHERE rnk = 1
ORDER BY Total_Spent DESC;


--Q9 Find the total revenue and number of tickets sold for each airline, and rank the airlines based on total revenue.


SELECT RANK() OVER (ORDER BY COALESCE(SUM(t.Price), 0) DESC) AS Revenue_Rank,
       al.Name                                                AS Airline,
       COUNT(t.TicketID)                                      AS Tickets_Sold,
       COALESCE(SUM(t.Price), 0)                              AS Total_Revenue
FROM dbo.Airlines al
LEFT JOIN dbo.Flights f ON f.AirlineID = al.AirlineID
LEFT JOIN dbo.Tickets t ON t.FlightID  = f.FlightID
GROUP BY al.AirlineID, al.Name
ORDER BY Revenue_Rank, Airline;


--Q10 For each passenger, identify their most frequently used airline, if a passenger has multiple airlines with the same highest usage, show all such airlines.



WITH AirlineUsage AS (
    SELECT
        p.PassengerID,
        p.Name AS Passenger_Name,
        p.FrequentFlyerStatus,
        a.AirlineID,
        a.Name AS Airline_Name,
        COUNT(t.TicketID) AS Flights_Used
    FROM dbo.Passengers AS p
    JOIN dbo.Tickets AS t
        ON p.PassengerID = t.PassengerID
    JOIN dbo.Flights AS f
        ON t.FlightID = f.FlightID
    JOIN dbo.Airlines AS a
        ON f.AirlineID = a.AirlineID
    GROUP BY
        p.PassengerID,
        p.Name,
        p.FrequentFlyerStatus,
        a.AirlineID,
        a.Name
),
RankedAirlines AS (
    SELECT
        *,
        RANK() OVER (
            PARTITION BY PassengerID
            ORDER BY Flights_Used DESC
        ) AS Usage_Rank
    FROM AirlineUsage
)
SELECT
    PassengerID,
    Passenger_Name,
    Airline_Name,
    Flights_Used
FROM RankedAirlines
WHERE Usage_Rank = 1
ORDER BY
    PassengerID,
    Airline_Name;












