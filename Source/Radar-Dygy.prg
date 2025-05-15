/*
 * Proyecto: Radar-Dygy
 * Fichero: Radar-Dygy.prg
 * Descripción: Módulo de entrada a la aplicación
 * Autor:
 * Fecha: 17/01/2023
 */

#include "Xailer.ch"

Procedure Main()

   Application:cTitle := "Radar-Dygy"

   AppData:AddData("oreceptor"   , nil)
   AppData:AddData("hdatos"      , {=>})

   principal():New( Application ):Show()

   Application:Run()

Return
