# Stat Architecture Notes

## Goal

The NBA terminal should eventually support much deeper statistical views than the first MVP. The first build still needs to stay practical: player identity, player season stats, team season stats, standings, games, awards, and playoff splits come before every advanced metric family.

## Core stat groups

The product should separate stats into clear families instead of putting everything into one wide table.

Core box score stats should include points, rebounds, assists, steals, blocks, turnovers, personal fouls, made shots, shot attempts, made threes, three point attempts, made free throws, free throw attempts, shooting percentages, minutes, games, and starts.

Efficiency stats should include true shooting, effective field goal rate, field goal percentage, three point percentage, free throw percentage, points per possession, usage, offensive rating, defensive rating, net rating, pace, and assist to turnover ratio.

Advanced box metrics should include PER, BPM, VORP, win shares, offensive win shares, defensive win shares, box plus minus, steal rate, block rate, assist rate, rebound rate, offensive rebound rate, defensive rebound rate, and turnover rate.

Tracking and play type stats should include deflections, forced turnovers, charges drawn, offensive fouls drawn, drives, potential assists, shot contests, defensive field goal percentage, catch and shoot, spot up, transition, isolation, pick and roll, and other possession type metrics.

Third party or proprietary style metrics such as EPM, DARKO, LEBRON, BPR, and gravity should be clearly separated from official source data and should only be added when source rights are clear.

## Display modes

Stats should eventually support per game, minute normalized, possession normalized, totals, percentage views, regular season, playoffs, and combined views. The MVP should keep regular season and playoffs as first class season types from the beginning.

## Charts

The long term interface should include trend charts over seasons and games. A player, team, lineup, or metric should be selectable, and the chart should support date or season ranges similar to a finance chart. This should come after the data model and real rows are stable.
