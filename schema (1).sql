-- MySQL dump 10.13  Distrib 8.0.46, for Win64 (x86_64)
--
-- Host: localhost    Database: cold_chain_db
-- ------------------------------------------------------
-- Server version	8.0.46

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Temporary view structure for view `excursion_report_view`
--

DROP TABLE IF EXISTS `excursion_report_view`;
/*!50001 DROP VIEW IF EXISTS `excursion_report_view`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `excursion_report_view` AS SELECT 
 1 AS `excursion_id`,
 1 AS `shipment_id`,
 1 AS `product_name`,
 1 AS `excursion_type`,
 1 AS `duration_minutes`,
 1 AS `severity`,
 1 AS `excursion_status`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `shipment_details_view`
--

DROP TABLE IF EXISTS `shipment_details_view`;
/*!50001 DROP VIEW IF EXISTS `shipment_details_view`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `shipment_details_view` AS SELECT 
 1 AS `shipment_id`,
 1 AS `product_name`,
 1 AS `origin`,
 1 AS `destination`,
 1 AS `status`,
 1 AS `planned_departure`,
 1 AS `actual_delivery`*/;
SET character_set_client = @saved_cs_client;

--
-- Final view structure for view `excursion_report_view`
--

/*!50001 DROP VIEW IF EXISTS `excursion_report_view`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `excursion_report_view` AS select `e`.`excursion_id` AS `excursion_id`,`e`.`shipment_id` AS `shipment_id`,`p`.`product_name` AS `product_name`,`e`.`excursion_type` AS `excursion_type`,`e`.`duration_minutes` AS `duration_minutes`,`e`.`severity` AS `severity`,`e`.`excursion_status` AS `excursion_status` from ((`excursions` `e` join `shipments` `s` on((`e`.`shipment_id` = `s`.`shipment_id`))) join `products` `p` on((`s`.`product_id` = `p`.`product_id`))) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `shipment_details_view`
--

/*!50001 DROP VIEW IF EXISTS `shipment_details_view`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `shipment_details_view` AS select `s`.`shipment_id` AS `shipment_id`,`p`.`product_name` AS `product_name`,`s`.`origin` AS `origin`,`s`.`destination` AS `destination`,`s`.`status` AS `status`,`s`.`planned_departure` AS `planned_departure`,`s`.`actual_delivery` AS `actual_delivery` from (`shipments` `s` join `products` `p` on((`s`.`product_id` = `p`.`product_id`))) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-11-01  0:02:36
