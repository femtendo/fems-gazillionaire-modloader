package
{
   import flash.net.getClassByAlias;
   import flash.net.registerClassAlias;
   import flash.system.*;
   import flash.utils.*;
   import mx.accessibility.AlertAccImpl;
   import mx.accessibility.ButtonAccImpl;
   import mx.accessibility.ComboBaseAccImpl;
   import mx.accessibility.ComboBoxAccImpl;
   import mx.accessibility.LabelAccImpl;
   import mx.accessibility.ListAccImpl;
   import mx.accessibility.ListBaseAccImpl;
   import mx.accessibility.PanelAccImpl;
   import mx.accessibility.UIComponentAccProps;
   import mx.collections.ArrayCollection;
   import mx.collections.ArrayList;
   import mx.core.IFlexModuleFactory;
   import mx.core.mx_internal;
   import mx.effects.EffectManager;
   import mx.managers.systemClasses.ChildManager;
   import mx.styles.IStyleManager2;
   import mx.styles.StyleManagerImpl;
   import mx.utils.ObjectProxy;
   
   [Mixin]
   public class _Gazillionaire_FlexInit
   {
      
      public function _Gazillionaire_FlexInit()
      {
         super();
      }
      
      public static function init(param1:IFlexModuleFactory) : void
      {
         var styleNames:Array;
         var i:int;
         var styleManager:IStyleManager2 = null;
         var fbs:IFlexModuleFactory = param1;
         new ChildManager(fbs);
         styleManager = new StyleManagerImpl(fbs);
         EffectManager.mx_internal::registerEffectTrigger("addedEffect","added");
         EffectManager.mx_internal::registerEffectTrigger("closeEffect","windowClose");
         EffectManager.mx_internal::registerEffectTrigger("completeEffect","complete");
         EffectManager.mx_internal::registerEffectTrigger("creationCompleteEffect","creationComplete");
         EffectManager.mx_internal::registerEffectTrigger("focusInEffect","focusIn");
         EffectManager.mx_internal::registerEffectTrigger("focusOutEffect","focusOut");
         EffectManager.mx_internal::registerEffectTrigger("hideEffect","hide");
         EffectManager.mx_internal::registerEffectTrigger("itemsChangeEffect","itemsChange");
         EffectManager.mx_internal::registerEffectTrigger("minimizeEffect","windowMinimize");
         EffectManager.mx_internal::registerEffectTrigger("mouseDownEffect","mouseDown");
         EffectManager.mx_internal::registerEffectTrigger("mouseUpEffect","mouseUp");
         EffectManager.mx_internal::registerEffectTrigger("moveEffect","move");
         EffectManager.mx_internal::registerEffectTrigger("removedEffect","removed");
         EffectManager.mx_internal::registerEffectTrigger("resizeEffect","resize");
         EffectManager.mx_internal::registerEffectTrigger("resizeEndEffect","resizeEnd");
         EffectManager.mx_internal::registerEffectTrigger("resizeStartEffect","resizeStart");
         EffectManager.mx_internal::registerEffectTrigger("rollOutEffect","rollOut");
         EffectManager.mx_internal::registerEffectTrigger("rollOverEffect","rollOver");
         EffectManager.mx_internal::registerEffectTrigger("showEffect","show");
         EffectManager.mx_internal::registerEffectTrigger("unminimizeEffect","windowUnminimize");
         if(Capabilities.hasAccessibility)
         {
            ListAccImpl.enableAccessibility();
            AlertAccImpl.enableAccessibility();
            ComboBoxAccImpl.enableAccessibility();
            LabelAccImpl.enableAccessibility();
            PanelAccImpl.enableAccessibility();
            ListBaseAccImpl.enableAccessibility();
            ButtonAccImpl.enableAccessibility();
            ComboBaseAccImpl.enableAccessibility();
            UIComponentAccProps.enableAccessibility();
         }
         try
         {
            if(getClassByAlias("flex.messaging.io.ArrayCollection") != ArrayCollection)
            {
               registerClassAlias("flex.messaging.io.ArrayCollection",ArrayCollection);
            }
         }
         catch(e:Error)
         {
            registerClassAlias("flex.messaging.io.ArrayCollection",ArrayCollection);
         }
         try
         {
            if(getClassByAlias("flex.messaging.io.ArrayList") != ArrayList)
            {
               registerClassAlias("flex.messaging.io.ArrayList",ArrayList);
            }
         }
         catch(e:Error)
         {
            registerClassAlias("flex.messaging.io.ArrayList",ArrayList);
         }
         try
         {
            if(getClassByAlias("flex.messaging.io.ObjectProxy") != ObjectProxy)
            {
               registerClassAlias("flex.messaging.io.ObjectProxy",ObjectProxy);
            }
         }
         catch(e:Error)
         {
            registerClassAlias("flex.messaging.io.ObjectProxy",ObjectProxy);
         }
         styleNames = ["lineHeight","unfocusedTextSelectionColor","kerning","iconColor","listAutoPadding","showErrorTip","textDecoration","dominantBaseline","buttonPadding","fontThickness","textShadowColor","blockProgression","textAlignLast","listStylePosition","buttonAlignment","textShadowAlpha","textAlpha","chromeColor","rollOverColor","fontSize","paragraphEndIndent","fontWeight","breakOpportunity","leading","symbolColor","renderingMode","paragraphStartIndent","layoutDirection","footerColors","contentBackgroundColor","statusTextStyleName","paragraphSpaceAfter","columnBreakBefore","titleTextStyleName","digitWidth","touchDelay","ligatureLevel","firstBaselineOffset","fontLookup","paragraphSpaceBefore","fontFamily","lineThrough","alignmentBaseline","trackingLeft","fontStyle","dropShadowColor","accentColor","selectionColor","titleBarBackgroundSkin","dropdownBorderColor","disabledIconColor","textJustify","focusColor","alternatingItemColors","typographicCase","containerBreakBefore","textRollOverColor"
         ,"showErrorSkin","digitCase","inactiveTextSelectionColor","justificationRule","statusBarBackgroundColor","titleAlignment","trackingRight","leadingModel","selectionDisabledColor","letterSpacing","focusedTextSelectionColor","baselineShift","titleBarColors","containerBreakAfter","barColor","fontSharpness","modalTransparencyDuration","justificationStyle","listStyleType","wordSpacing","contentBackgroundAlpha","fontAntiAliasType","textRotation","errorColor","direction","cffHinting","locale","backgroundDisabledColor","modalTransparencyColor","textIndent","themeColor","clearFloats","modalTransparency","tabStops","textAlign","headerColors","textSelectedColor","interactionMode","labelWidth","whiteSpaceCollapse","fontGridFitType","statusBarBackgroundSkin","disabledColor","modalTransparencyBlur","downColor","color","columnBreakAfter"];
         i = 0;
         while(i < styleNames.length)
         {
            styleManager.registerInheritingStyle(styleNames[i]);
            i++;
         }
      }
   }
}

