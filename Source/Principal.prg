/*
 * Proyecto: Radar-Dygy
 * Fichero: Principal.prg
 * Descripci�n:
 * Autor:
 * Fecha: 17/01/2023
 */

#include "Xailer.ch"

CLASS principal FROM TForm

   COMPONENT oRevisa

   METHOD CreateForm()
   METHOD FormInitialize( oSender )
   METHOD redirecciona(ctexto)
   METHOD RevisaTimer( oSender )

ENDCLASS

#include "Principal.xfm"

//------------------------------------------------------------------------------

METHOD FormInitialize( oSender ) CLASS principal

   LOCAL hdatos:={=>}, cdatos:="", aparams:={}, neste

   SET DATE FORMAT "yyyy/mm/dd"

   LogFile(DToC(Date())+" "+Time()+"   $$$$ iniciando Aplicacion Radar-DyGy  "+Str(seconds(),12,4))

   logfile(dtoc(date())+"-"+time()+"   $$$$ inicializando objeto receptor en Radar-Dygy  "+Str(seconds(),12,4))

   *======================================================================================================================================
   * INICIALIZAMOS EL OBJETO RECEPTOR DE MENSAJES QUE VENDRAN DESDE EL CGI, AQUI LO DECLARAMOS Y LO ABRIMOS, ESTO POR SI SOLO NO CAPTARA
   * LOS MENSAJES QUE ENVIE LA APLICACION CGI, ES NECESARIO ESTAR REVISANDO PERIODICAMENTE SI SE HA RECIBIDO UN MENSAJE, PARA RESOLVER
   * ESTA CONDICION SE ACTIVARA EL TIMER ::OREVISA PARA QUE SU EVENTO :ONTIMER REALICE LAS FUNCIONES DE REVISION.
   *======================================================================================================================================

   appdata:oreceptor        := TMailSlotServer():Create()
   appdata:oreceptor:cName  := "radarDygy"

   if !appdata:oreceptor:Open()
      msginfo("no fue posible abrir receptor de mensajes desde appdata")
      Application:Terminate()
      ::End()
      return(nil)
   endif

   *======================================================================================================================================
   * CONFIGURAMOS EL EVENTO :ONREAD HACIA LA FUNCION ::REDIRECCIONA, ESTE EVENTO NO FUNCIONARA SI NO SE HACE UNA LLAMADA PERIODICA A LA
   * FUNCION :HASMESSAGES() DEL MISMO CONTROL, DE ESTO SE ENCARGARA EL TIMER ::OREVISA
   *======================================================================================================================================

   appdata:oreceptor:OnRead := {|o,cText| ::redirecciona(cText) }

   logfile(dtoc(date())+"-"+time()+"   $$$$ receptor Radar-Dygy declarado y activo "+Str(seconds(),12,4))

   *======================================================================================================================================
   * ACTIVAMOS EL TIMER DE REVISION
   *======================================================================================================================================

   ::oRevisa:lEnabled := .t.

RETURN Nil

//------------------------------------------------------------------------------

METHOD redirecciona(ctexto) CLASS principal

   LOCAL hpaso:={=>}, hestado:= {=>}

   logfile(dtoc(date())+"-"+time() + "   $$$$ entro a metodo redirecciona en Radar-Dygy     "+Str(seconds(),12,4))
   *logfile(dtoc(date())+"-"+time() + "   $$$$ entro a metodo redirecciona en Radar-Rezta datos recibidos=" + ctexto + "    "+Str(seconds(),12,4))


   *======================================================================================================================================
   * LLEGAMOS A ESTA FUNCION DESDE EL EVENTO :ONREAD DEL CONTROL TMAILSLOTSERVER, RECIBIMOS COMO PARAMETRO UN TEXTO, QUE EN ESTE CASO ES
   * UNA VARIABLE JSON CONTENIENDO LOS DATOS DE HREPORTE.
   *======================================================================================================================================


   *======================================================================================================================================
   * DECODIFICAMOS LA CADENA CTEXTO Y A LA VEZ LA PASAMOS A LA VARIABLE APPDATA:HDATOS
   *======================================================================================================================================

   HB_JsonDecode( ctexto, @appdata:hdatos)

   *======================================================================================================================================
   * REVISAMOS QUE LA VARIABLE APPDATA:HDATOS (HREPORTE) TENGA LOS PARAMETROS MINIMOS PARA MANDAR LLAMAR A LA APLICACION API
   *======================================================================================================================================

   if !hb_HHasKey( appdata:hdatos, "cprograma_api" ) .or. !hb_HHasKey( appdata:hdatos, "carchivo_json" )

      *======================================================================================================================================
      * PARA LLAMAR A LA API SOLO REQUERIMOS 2 PARAMETROS (cProgramaApi y cJson), SI FALTA ALGUNO DE ELLOS NO PODEMOS HACER LA LLAMADA POR
      * LO QUE ABORTAMOS MANDANDOLE SEҁL A LA APLICACION CGI DE LA CANCELACION DE LA PETICION.
      *======================================================================================================================================

      inicializa_estructura_estado_peticion_api( @hestado )

      hestado["cEstado"]                   := "Cancelado"
      hestado["cDescripcion"]              := "Radar no puede obtener el programa api o la ruta del archivo json"
      hestado["cTituloTextoUsuario"]       := "El sistema ha detectado un problema con su peticion"
      hestado["cTextoUsuario"]             := "Reporte este mensaje a su asesor de sistemas"

      logfile(dtoc(date())+"-"+time()+"   $$$$ en grabacion de error Radar-Dygy  appdata:hdatos[carchivo_error] = " + appdata:hdatos["carchivo_error"] + "    "+Str(seconds(),12,4))

      hb_memowrit( appdata:hdatos["carchivo_error"], HB_JsonEncode( hestado ))

      logfile(dtoc(date())+"-"+time()+"   $$$$ grabando error por falta de parametros basicos en RADAR-DYGY " + "    "+Str(seconds(),12,4))

      return(nil)

   endif

   *======================================================================================================================================
   * MANDAMOS PRIMER MENSAJE A CGI, PARA QUE SE ENTERE QUE LA PETICION LA RECIBIO RADAR, QUE EL PROCESO SIGUE.
   *======================================================================================================================================

   inicializa_estructura_estado_peticion_api( @hestado )

   hestado["cEstado"]                   := "Recibido"
   hestado["cDescripcion"]              := "RADAR recibio peticion y solicitara a API la creacion del archivo"
   hestado["cTituloTextoUsuario"]       := "Peticion Recibida, en breve obtendra respuesta..."
   hestado["cTextoUsuario"]             := "Un Momento..."

   logfile(dtoc(date())+"-"+time()+"   $$$$ en RADAR-DYGY mandando primer mensaje a CGI     "+Str(seconds(),12,4))

   hb_memowrit( appdata:hdatos["carchivo_avances"], HB_JsonEncode( hestado ))

   *===============================================================================================================================================================================
   * EJECUTAMOS LA APLICACION API
   *===============================================================================================================================================================================

   hpaso["cprograma"]:=appdata:hdatos["cprograma_api"] + ' "' + appdata:hdatos["carchivo_json"] + ' " '

   logfile(dtoc(date())+"-"+time()+"   $$$$ en RADAR-DYGY antes de ejecutar winexec hpaso[cprograma]="+hpaso["cprograma"] + "    "+Str(seconds(),12,4))

   *===============================================================================================================================================================================
   * VALIDAMOS QUE EL PROGRAMA API EXISTA, EN CASO DE NO EXISTIR MANDAREMOS ERROR A CGI
   *===============================================================================================================================================================================

   if !File(appdata:hdatos["cprograma_api"])

      inicializa_estructura_estado_peticion_api( @hestado )

      hestado["cEstado"]                   := "Cancelado"
      hestado["cDescripcion"]              := "Radar detecto que el programa API no existe, verifique la ruta"
      hestado["cTituloTextoUsuario"]       := "El sistema ha detectado un problema con su peticion"
      hestado["cTextoUsuario"]             := "Reporte este mensaje a su asesor de sistemas"

      hb_memowrit( appdata:hdatos["carchivo_error"], HB_JsonEncode( hestado ))

      logfile(dtoc(date())+"-"+time()+"        $#$# ERROR RADAR DETECTO QUE EL PROGRAMA API NO EXISTE   "+Str(seconds(),12,4))

      return(nil)

   endif

   hpaso["nresultado"] := WinExec( hpaso["cprograma"], 0 )

   *===============================================================================================================================================================================
   * LA RESPUESTA CORRECTA QUE DEBE DEVOLVER LA FUNCION WINEXEC ES 33, CUALQUIER OTRO RESULTADO ES ERROR Y DEBEMOS ENVIAR MENSAJE A CGI
   *===============================================================================================================================================================================

   if hpaso["nresultado"] <> 33

      inicializa_estructura_estado_peticion_api( @hestado )

      hestado["cEstado"]                   := "Cancelado"
      hestado["cDescripcion"]              := "Radar detecto que ocurrio un error al ejecutar el API, verifique en log de radar el codigo de error"
      hestado["cTituloTextoUsuario"]       := "El sistema ha detectado un problema con su peticion"
      hestado["cTextoUsuario"]             := "Reporte este mensaje a su asesor de sistemas"

      hb_memowrit( appdata:hdatos["carchivo_error"], HB_JsonEncode( hestado ))

      logfile(dtoc(date())+"-"+time()+"        $#$# ERROR RADAR DETECTO CODIGO DE ERROR AL EJECUTAR EL PROGRAMA API   "+Str(seconds(),12,4))

      return(nil)

   endif

   logfile(dtoc(date())+"-"+time()+"   $$$$ despues de ejecutar winexec nresultado = " + ToString(hpaso["nresultado"]) + "    "+Str(seconds(),12,4))

   logfile(dtoc(date())+"-"+time()+"   $$$$ en redirecciona de RADAR-DYGY llamo a ejecutable api y sale de metodo redirecciona" + "    "+Str(seconds(),12,4))

RETURN Nil

//------------------------------------------------------------------------------

METHOD RevisaTimer( oSender ) CLASS principal

  * logfile(dtoc(date())+"-"+time()+"   $$$$ revisando llamadas en receptor de Radar-Rezta" + "    "+Str(seconds(),12,4))

  *--------------------------------------------------------------------------------------------------------------------------------------
  * LA REVISION SE CONFIGURO PARA QUE SE EFECTUE CADA SEGUNDO, EN CASO DE ENCONTRAR UN MENSAJE SE ACTIVARA EL EVENTO :ONREAD
  *--------------------------------------------------------------------------------------------------------------------------------------

  IF appdata:oreceptor:HasMessages()
    logfile(dtoc(date())+"-"+time()+"   $$$$ llamada detectada en receptor de RADAR-DYGY" + "    "+Str(seconds(),12,4))
    appdata:oreceptor:Read()
  ENDIF

RETURN Nil

//------------------------------------------------------------------------------
