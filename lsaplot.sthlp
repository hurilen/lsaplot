{smcl}
{* 2025-12-23}{...}
{hline}
帮助文件: lsaplot
{hline}

{title:lsaplot - 绘制事件研究法结果图}

{section:语法}
    lsaplot varlist [if] [in] [, options]

{section:描述}
    lsaplot命令用于绘制事件研究法（Event Study）的系数图，包括平行趋势检验。

{section:选项}
    {opt pre(# #)}: 指定政策前时期范围
    {opt post(# #)}: 指定政策后时期范围
    {opt ci(level)}: 置信区间水平，默认95%
    {opt title(string)}: 图形标题
    {opt ytitle(string)}: Y轴标题
    {opt xtitle(string)}: X轴标题

{section:示例}
    {stata sysuse auto, clear}
    {stata lsaplot mpg price weight, pre(5 1) post(0 5)}

{section:作者}
    李三安
    Email: lilinze626@gmail.com

{hline}
