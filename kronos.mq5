//+------------------------------------------------------------------+
//|                                                      Pecunia.mq5 |
//|                                                  Josep Capdevila |
//|                                                jspcapi@gmail.com |
//+------------------------------------------------------------------+
#property copyright     "Email: Josep Capdevila"
#property link          "jspcapi@gmail.com"
#property version       "1.00"
#property description   "► Sistema con una operativa de medio largo plazo"
#property description   "  que opera la corrección de los rangos."
#property strict
#define Bid_ SymbolInfoDouble(_Symbol,SYMBOL_BID)
#define Ask_ SymbolInfoDouble(_Symbol,SYMBOL_ASK)
//+------------------------------------------------------------------+
//| Librerías                                                        |
//+------------------------------------------------------------------+
#include <Trade\PositionInfo.mqh>
CPositionInfo m_position;

#include <Trade\Trade.mqh>
CTrade m_trade;

#include <Trade\OrderInfo.mqh>
COrderInfo m_order;
enum sino{
   no =  0, //NO
   si =  1  //SI
};


enum type_{
   type_0   =  0, //"Lotaje"
   type_1   =  1, //"Balance"
   type_2   =  2  //"Equity"
};
//+------------------------------------------------------------------------------------------------------------------------------------------------+
sinput string     Parametros                 =  "---------- Parámetros ----------";          //_1
input int         Numero_Magico              =  100;                                         //Número Mágico
input int         Max_Spread                 =  3;                                           //Máximo Spread Permitido
input int         Maximo_Slippage            =  2;                                           //Máximo Slippage Permitido
input int         Numero_Velas_Rango         =  6;                                           //Número Velas Rango
input int         Distancia_Minima_Rango     =  500;                                         //Distancia Mínima Rango
input int         Correccion_Rango_Compra    =  300;                                         //Corrección Rango Compra
input int         Correccion_Rango_Venta     =  300;                                         //Corrección Rango Venta
input int         Limite_Ultima_Vela         =  750;                                         //Limite Ultima Vela
//+-------------------------------------------------------------------------------------------------------------------------------------------------+
sinput string     Gestion_Monetaria          =  "---------- Gestión Monetaria ----------";   //_2
input type_       Tipo_Gestion               = 0;                                            //Tipo de Gestión
input double      Lote_FIjo                  =  0.04;                                        //Lotaje Fijo 1
input double      Equity                     =  1;                                           //Riesgo porcentual por Equity Lotaje %
input double      Balance                    =  1;                                           //Riesgo porcentual por Balance Lotaje %
//+-------------------------------------------------------------------------------------------------------------------------------------------------+
sinput string     Gestion_Riesgo             =  "---------- Gestión del Riesgo ----------";  //_3
input int         TakeProfit                 =  140;                                         //Take Profit
input int         Distancia_Maxima_StopLoss  =  750;                                         //Distancia Máxima StopLoss
input int         Activacion_Trailing_Pips   =  5;                                           //Activación Trailing
input int         Distancia_Trailing_Stop    =  10;                                          //Distancia Trailing
input int         Break_Even                 =  0;                                           //Break Even             
//+-------------------------------------------------------------------------------------------------------------------------------------------------+
sinput string     Horario_Trading            =  "---------- Horario de Trading ----------";  //_4
input sino        hor_bool                   =  0;                                           //Usa el tiempo de trabajo
input int         hour_start                 =  8;                                           //Hora de activación
input int         minute_start               =  0;                                           //Minutos de activación
input int         hour_end                   =  15;                                          //Hora de desactivación
input int         minute_end                 =  0;                                           //Minutos de desactivación
input int         hour_close                 =  18;                                          //Hora de cierre
input int         minu_close                 =  00;                                          //Minutos de cierre               
//+-------------------------------------------------------------------------------------------------------------------------------------------------+
//sinput   string Panel_Informativo          =  "---------- Panel Informativo ----------";   //_5
//input bool      Mostrar_Panel              =  true;                                        //Mostrar Panel ► True / False
//+-------------------------------------------------------------------------------------------------------------------------------------------------+
double               InpTrailingStop   = Activacion_Trailing_Pips;                                    //Trailing Stop in points
double               InpTrailingStep   = Distancia_Trailing_Stop;                                     //Trailing Step in points
double               ExtTrailingStop   = 0;
double               ExtTrailingStep   = 0;


int HoraCorrecta=0;
MqlDateTime Hora;
double lot_1=0.0;
double lot_step, lot_max, lot_min, tick_size;
int sessionStart, sessionEnd;
bool buy_allow=false,sell_allow=false;
double max_=0,min_=0;
bool BE_buy=true,BE_sell=true;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   m_trade.SetExpertMagicNumber(Numero_Magico);
   m_trade.SetDeviationInPoints(Maximo_Slippage*10);
   lot_step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   lot_max=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   lot_min=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   ExtTrailingStop=InpTrailingStop  *_Point;
   ExtTrailingStep=InpTrailingStep  *_Point;

   MqlDateTime sStart, sEnd;
   datetime time_day=iTime(_Symbol,PERIOD_D1,0);
   TimeToStruct(time_day+hour_start*3600+minute_start*60,sStart);
   TimeToStruct(time_day+hour_end*3600+minute_end*60,sEnd);
     
   sessionStart=sStart.hour*60+sStart.min;
   sessionEnd=sEnd.hour*60+sEnd.min;
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   static datetime Old_Time;
   datetime New_Time[1];
   bool IsNewBar=false;
   int copied=CopyTime(_Symbol,0,0,1,New_Time);
   if(copied>0) // ok, the data has been copied successfully
     {
      if(Old_Time!=New_Time[0]) // if old time isn't equal to new bar time
        {
         IsNewBar=true;   // if it isn't a first call, the new bar has appeared
         //    if(MQL5InfoInteger(MQL5_DEBUGGING)) Print("We have new bar here ",New_Time[0]," old time was ",Old_Time);
         Old_Time=New_Time[0];            // saving bar time
        }
     }
   else
     {
      Alert("Error in copying historical times data, error =",GetLastError());
      ResetLastError();
      return;
     }
   if(NumberPositionExistsBuy(Numero_Magico)==0)BE_buy=true;
   if(NumberPositionExistsSell(Numero_Magico)==0)BE_sell=true;
   if(( (NumberPositionExistsBuy(Numero_Magico)!=0 && BE_buy) || (NumberPositionExistsSell(Numero_Magico)!=0 && BE_sell) ) && Break_Even!=0 && Break_Even>=30)CheckBE();
   double max_price=0,min_price=0;
   int high=iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,Numero_Velas_Rango,1);
   int low=iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,Numero_Velas_Rango,1);
   max_price=iHigh(_Symbol,PERIOD_CURRENT,high);
   min_price=iLow(_Symbol,PERIOD_CURRENT,low);
   //if(NumberPositionExistsBuy(Numero_Magico)==0 || NumberPositionExistsSell(Numero_Magico)==0)
   buy_allow=false;
   sell_allow=false;
   if(IsNewBar && high==1 && CheckCandleRange() && (max_price-min_price)>=Distancia_Minima_Rango*_Point && (max_price-iClose(_Symbol,PERIOD_CURRENT,1))<Correccion_Rango_Compra*_Point)
         sell_allow=true;
   if(IsNewBar && low==1 && CheckCandleRange() && (max_price-min_price)>=Distancia_Minima_Rango*_Point && (iClose(_Symbol,PERIOD_CURRENT,1)-min_price)<Correccion_Rango_Venta*_Point)
         buy_allow=true;
         
   if(IsNewBar && high>1 && high<low && CheckCandleRange() && (max_price-min_price)>=Distancia_Minima_Rango*_Point)
      {
         for(int i=high-1;i>0;i--)
            if((max_price-iLow(_Symbol,PERIOD_CURRENT,i))>Correccion_Rango_Compra*_Point)
               {
                  buy_allow=true;
                  break;
               }
               else buy_allow=false;
      };
   if(IsNewBar && low>1 && low<high && CheckCandleRange() && (max_price-min_price)>=Distancia_Minima_Rango*_Point)
      {
         for(int i=low-1;i>0;i--)
            if((iLow(_Symbol,PERIOD_CURRENT,i)-min_price)>Correccion_Rango_Venta*_Point)
               {
                  sell_allow=true;
                  break;
               }
               else sell_allow=false;
      }; 
   long spred_=SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   
   TimeToStruct(TimeGMT(),Hora);
   if(hor_bool==1 && (NumberOrdersExistsBuy(Numero_Magico)!=0 || NumberOrdersExistsSell(Numero_Magico)!=0) 
      && (Hora.hour*3600+Hora.min*60)>=(hour_close*3600+minu_close*60) )
         {
            DeleteOrders();
         };
   HoraCorrecta=0;
   if(hor_bool==1 && IsTime()) 
      {
         HoraCorrecta=1;
      };
   if(hor_bool==0)HoraCorrecta=1;
   if (Tipo_Gestion==0)
      lot_1=NormalizeLot(_Symbol,Lote_FIjo);
   if (Tipo_Gestion==1)
      lot_1=AccountInfoDouble(ACCOUNT_BALANCE)*Balance/SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE);
   if (Tipo_Gestion==2)
      lot_1=AccountInfoDouble(ACCOUNT_EQUITY)*Equity/SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE);
   
   if(buy_allow && Max_Spread*10>spred_ && NumberPositionExistsBuy(Numero_Magico)==0 && NumberOrdersExistsBuy(Numero_Magico)==0 && HoraCorrecta==1)
      {
         datetime time_expir=TimeCurrent()+349980;
         double SL=min_price;
         if( (max_price-SL)>=Distancia_Maxima_StopLoss*_Point)SL=max_price-Distancia_Maxima_StopLoss*_Point;
         m_trade.OrderOpen(_Symbol,ORDER_TYPE_BUY_STOP,NormalizeLot(_Symbol,lot_1),0,max_price,SL,max_price+TakeProfit*_Point,ORDER_TIME_SPECIFIED,time_expir,"BUY_STOP_1");
         buy_allow=false;
      };
   if(sell_allow && Max_Spread*10>spred_ && NumberPositionExistsSell(Numero_Magico)==0 && NumberOrdersExistsSell(Numero_Magico)==0 && HoraCorrecta==1)
      {
         datetime time_expir=TimeCurrent()+349980;
         double SL=max_price;
         if( (SL-min_price)>=Distancia_Maxima_StopLoss*_Point)SL=min_price+Distancia_Maxima_StopLoss*_Point;
         m_trade.OrderOpen(_Symbol,ORDER_TYPE_SELL_STOP,NormalizeLot(_Symbol,lot_1),0,min_price,SL,min_price-TakeProfit*_Point,ORDER_TIME_SPECIFIED,time_expir,"SELL_STOP_1");
         sell_allow=false;
      };
   Trailing();
  }
//+------------------------------------------------------------------+

void CheckBE()
   {
      for(int i=PositionsTotal()-1;i>=0;i--)
        {
         if(m_position.SelectByIndex(i)) // selects the position by index for further access to its properties
            if(m_position.Symbol()==_Symbol && m_position.Magic()==Numero_Magico)
               {
                  if(m_position.PositionType()==POSITION_TYPE_BUY && Bid_>=m_position.PriceOpen()+Break_Even*_Point 
                     && m_position.StopLoss()<=m_position.PriceOpen())
                       {
                        m_trade.PositionModify(m_position.Ticket(),m_position.PriceOpen(),m_position.TakeProfit());
                        BE_buy=false;
                       }
                  if(m_position.PositionType()==POSITION_TYPE_SELL && Ask_<m_position.PriceOpen()-Break_Even*_Point
                     && m_position.StopLoss()>=m_position.PriceOpen())
                       {
                        m_trade.PositionModify(m_position.Ticket(),m_position.PriceOpen(),m_position.TakeProfit());
                        BE_sell=false;
                       }
               };
        }
   };

bool CheckCandleRange()
   {
      for(int i=1;i<=Numero_Velas_Rango;i++)
         if((iHigh(_Symbol,PERIOD_CURRENT,i)-iLow(_Symbol,PERIOD_CURRENT,i))>Limite_Ultima_Vela*_Point)return(false);
      return(true);
   };
   
int NumberOrdersExistsBuy(int magic)
  {
   int buynumber=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(m_order.SelectByIndex(i)) // selects the position by index for further access to its properties
         if(m_order.Symbol()==_Symbol)
            if(m_order.OrderType()==ORDER_TYPE_BUY_STOP && m_order.Magic()==magic)
              {
               buynumber++;
              }
     }
   return(buynumber);
  }
  
int NumberOrdersExistsSell(int magic)
  {
   int buynumber=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(m_order.SelectByIndex(i)) // selects the position by index for further access to its properties
         if(m_order.Symbol()==_Symbol)
            if(m_order.OrderType()==ORDER_TYPE_SELL_STOP && m_order.Magic()==magic)
              {
               buynumber++;
              }
     }
   return(buynumber);
  }

int NumberPositionExistsBuy(int magic)
  {
   int buynumber=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      if(m_position.SelectByIndex(i)) // selects the position by index for further access to its properties
         if(m_position.Symbol()==_Symbol)
            if(m_position.PositionType()==POSITION_TYPE_BUY && m_position.Magic()==magic)
              {
               buynumber++;
              }
     }
   return(buynumber);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Number Sell position                                               |
//+------------------------------------------------------------------+
int NumberPositionExistsSell(int magic)
  {
   int sellnumber=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      if(m_position.SelectByIndex(i)) // selects the position by index for further access to its properties
         if(m_position.Symbol()==_Symbol)
            if(m_position.PositionType()==POSITION_TYPE_SELL && m_position.Magic()==magic)
              {
               sellnumber++;
              }
     }
   return(sellnumber);
  }
  
void Trailing()
  {
   if(InpTrailingStop==0 && InpTrailingStep==0)
      return;
   for(int i=PositionsTotal()-1;i>=0;i--) // returns the number of open positions
      if(m_position.SelectByIndex(i))
         if(m_position.Symbol()==_Symbol && m_position.Magic()==Numero_Magico)
           {
            if(m_position.PositionType()==POSITION_TYPE_BUY)
              {
               if(InpTrailingStop!=0)
                  if(m_position.PriceCurrent()-m_position.PriceOpen()>ExtTrailingStop+ExtTrailingStep)
                     if(m_position.StopLoss()<m_position.PriceCurrent()-(ExtTrailingStop+ExtTrailingStep))
                       {
                        if(!m_trade.PositionModify(m_position.Ticket(),
                           NormalizeDouble(m_position.PriceCurrent()-ExtTrailingStop,_Digits),
                           m_position.TakeProfit()))
                           Print("Modify BUY ",m_position.Ticket(),
                                 " Position -> false. Result Retcode: ",m_trade.ResultRetcode(),
                                 ", description of result: ",m_trade.ResultRetcodeDescription());
                        continue;
                       }
              }
            else
              {
               if(InpTrailingStop!=0)
                  if(m_position.PriceOpen()-m_position.PriceCurrent()>ExtTrailingStop+ExtTrailingStep)
                     if((m_position.StopLoss()>(m_position.PriceCurrent()+(ExtTrailingStop+ExtTrailingStep))) || 
                        (m_position.StopLoss()==0))
                       {
                        if(!m_trade.PositionModify(m_position.Ticket(),
                           NormalizeDouble(m_position.PriceCurrent()+ExtTrailingStop,_Digits),
                           m_position.TakeProfit()))
                           Print("Modify SELL ",m_position.Ticket(),
                                 " Position -> false. Result Retcode: ",m_trade.ResultRetcode(),
                                 ", description of result: ",m_trade.ResultRetcodeDescription());
                       }
              }

           }
  }
  
void CloseAll()
{
   ClosePositions();
   DeleteOrders();
}
bool ClosePositions()
{
   bool closed=0;
   for (int i=PositionsTotal()-1; i>=0; i--)
      if (PositionGetSymbol(i)==_Symbol&&PositionGetInteger(POSITION_MAGIC)==Numero_Magico)
         if (m_trade.PositionClose((ulong)PositionGetInteger(POSITION_TICKET))){
            Print(_Symbol+(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?" Buy":" Sell")+": Posição fechada");
            closed=1;
         }
   return closed;
}
void DeleteOrders()
{
   for (int i=OrdersTotal()-1; i>=0; i--)
      if (OrderGetTicket(i))
         if (OrderGetString(ORDER_SYMBOL)==_Symbol&&OrderGetInteger(ORDER_MAGIC)==Numero_Magico)
            m_trade.OrderDelete(OrderGetInteger(ORDER_TICKET));
}


double LotBuy()
   {
      double lots1=0,sum=0;
      int kol_pos=0;
      for(int i=PositionsTotal()-1; i>=0; i--)
        {
         if(m_position.SelectByIndex(i) && m_position.Symbol()==_Symbol)
           {
            if(m_position.PositionType()==POSITION_TYPE_BUY)
              {
               lots1+=m_position.Volume();
               sum+=m_position.Volume() *(m_position.PriceOpen());
               kol_pos++;
              }
           }
        }
      if(lots1==0)
         return (0);
      return (lots1);
   };

double LotSell()
   {
      double lots1=0,sum=0;
      int kol_pos=0;
      for(int i=PositionsTotal()-1; i>=0; i--)
        {
         if(m_position.SelectByIndex(i) && m_position.Symbol()==_Symbol)
           {
            if(m_position.PositionType()==POSITION_TYPE_SELL)
              {
               lots1+=m_position.Volume();
               sum+=m_position.Volume() *(m_position.PriceOpen());
               kol_pos++;
              }
           }
        }
      if(lots1==0)
         return (0);
      return (lots1);
   };
   
   
double NormalizeLot(string symbol,double value)
  {

   if(value<=lot_min) value=lot_min;                
   else if(value >= lot_max) value = lot_max;      
   else value = MathRound(value/lot_step)*lot_step; 
//---
   return(NormalizeDouble(value,2));
  }
  
  
bool IsTime()
{
   MqlDateTime time;
   TimeToStruct(TimeCurrent(),time);
   int mt5Hour=time.hour*60+time.min;
   if(sessionStart<sessionEnd)
      {
         if(mt5Hour>=sessionStart && mt5Hour<sessionEnd)
            return true;
         return false;
      }
   return true;
}