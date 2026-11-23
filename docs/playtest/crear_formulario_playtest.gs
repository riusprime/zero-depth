/**
 * Builds the friends' playtest form for Zero Depth in Google Forms, in Spanish, with a linked
 * Google Sheet for the answers.
 *
 * How to use it (2 minutes):
 *   1. Open https://script.google.com and click "Nuevo proyecto".
 *   2. Delete what is there, paste this whole file and save.
 *   3. Pick crearFormulario in the function list and click "Ejecutar". Google asks you once to
 *      allow the script to create forms and sheets in your account.
 *   4. Open "Registro de ejecución": it prints the link to send your friends, the link to edit
 *      the form and the link to the answers sheet.
 */
function crearFormulario() {
  var form = FormApp.create('Zero Depth: prueba con amigos');
  form.setDescription(
    'Gracias por probar Zero Depth. Juega unos 30-45 minutos y luego responde esto en 10 minutos.\n' +
    'No hay respuestas buenas ni malas: lo que no te guste nos ayuda más que un "está guay".\n' +
    'Juega sin que nadie te explique nada, y apunta en el móvil los momentos de "¿y esto qué es?", ' +
    '"¡qué bueno!" o "qué rollo".\n\n' +
    'En las notas: 1 = muy mal, 3 = normal, 5 = genial.'
  );
  form.setCollectEmail(false);
  form.setProgressBar(true);
  form.setConfirmationMessage('¡Gracias por jugar! Tus respuestas nos ayudan a mejorar el juego.');

  // Sobre ti
  seccion(form, 'Sobre ti y tu partida', '');
  form.addTextItem().setTitle('Tu nombre o apodo').setRequired(true);
  opciones(form, '¿Cuánto juegas a videojuegos?', ['Casi nada', 'A veces', 'Mucho'], true);
  opciones(form, '¿Has jugado roguelikes antes? (Hades, Binding of Isaac, Dead Cells…)',
    ['No', 'Alguno', 'Muchos'], true);
  opciones(form, '¿Con qué jugaste?', ['Teclado y ratón', 'Mando'], true);
  form.addTextItem().setTitle('¿Cuánto tiempo jugaste? (minutos)');
  form.addTextItem().setTitle('¿Cuántas partidas empezaste?');
  form.addTextItem().setTitle('¿Hasta dónde llegaste como máximo? (zona o jefe)');
  opciones(form, '¿Qué arma usaste más?', ['Pistola', 'Espada', 'Las dos por igual'], false);

  // Primeras impresiones
  seccion(form, 'Primeras impresiones y controles', '');
  nota(form, '¿Te gusta cómo se ve el juego?');
  nota(form, '¿Entendiste qué tenías que hacer sin que te lo explicaran?');
  nota(form, '¿Los controles responden bien? (moverse, esquivar, atacar)');
  nota(form, '¿Ves bien a tu personaje, a los enemigos y sus ataques?');
  nota(form, '¿El sonido y los efectos te dicen lo que pasa?');
  abierta(form, 'En una frase, ¿cómo le describirías el juego a un amigo?');
  abierta(form, '¿Hubo algo que no entendiste en los primeros 5 minutos?');

  // Combate
  seccion(form, 'Combate, enemigos y jefes', '');
  nota(form, '¿Es divertido pelear?');
  nota(form, '¿Sentías que los golpes (tuyos y suyos) pegaban fuerte?');
  nota(form, '¿Los enemigos son distintos entre sí y obligan a jugar distinto?');
  nota(form, '¿Veías venir los ataques a tiempo para esquivarlos?');
  nota(form, '¿Los jefes te parecieron justos?');
  abierta(form, '¿Qué enemigo o jefe te gustó más, y por qué?');
  abierta(form, '¿Cuál odiaste o te pareció injusto?');
  abierta(form, '¿Cómo moriste la mayoría de las veces? ¿Sabías qué te mató?');

  // Cartas y decisiones
  seccion(form, 'Cartas, objetos y decisiones', '');
  nota(form, '¿Entendías qué hacía cada carta u objeto antes de cogerlo?');
  nota(form, '¿Elegir cartas era una decisión interesante (no siempre la misma)?');
  nota(form, '¿Notabas que tu personaje se volvía más fuerte con lo que cogías?');
  nota(form, '¿Las tiendas, santuarios y salas especiales te tentaban a usarlos?');
  abierta(form, '¿Hubo alguna combinación de cartas que te hiciera sentir muy fuerte? ¿Cuál?');
  abierta(form, '¿Alguna carta u objeto te pareció inútil o confuso?');

  // Dificultad y ritmo
  seccion(form, 'Dificultad, ritmo y ganas de volver', '');
  opciones(form, 'La dificultad fue…', ['Demasiado fácil', 'Bien', 'Demasiado difícil'], true);
  abierta(form, '¿Hubo partes lentas o aburridas? ¿Cuáles?');
  abierta(form, '¿Hubo partes donde todo pasaba demasiado rápido para entenderlo?');
  opciones(form, 'Al morir, ¿querías volver a intentarlo enseguida?', ['Sí', 'Depende', 'No'], true);
  form.addScaleItem().setTitle('¿Qué probabilidad hay de que lo juegues otra vez por tu cuenta?')
    .setBounds(1, 10).setLabels('Ninguna', 'Seguro').setRequired(true);
  opciones(form, 'Si costara 10 €, ¿lo comprarías?', ['Sí', 'Quizás', 'No'], false);

  // Problemas
  seccion(form, 'Problemas, errores y rendimiento',
    'Apunta cualquier fallo, aunque parezca pequeño, y dónde estabas (zona, sala, jefe).');
  abierta(form, 'Fallos o cosas raras que viste (qué pasó, dónde y cuántas veces)');
  opciones(form, '¿El juego fue fluido?', ['Sí, siempre', 'Se trabó a veces', 'Se trabó mucho'], true);
  abierta(form, 'Si se trabó, ¿dónde? (zona, cuántos enemigos había)');
  form.addTextItem().setTitle('Tu ordenador (procesador y tarjeta gráfica, si lo sabes)');
  opciones(form, '¿Se cerró o se colgó el juego alguna vez?', ['No', 'Sí, una vez', 'Sí, varias'], true);

  // Cierre
  seccion(form, 'Lo mejor, lo peor y un cambio', '');
  abierta(form, 'Lo que más te gustó', true);
  abierta(form, 'Lo que menos te gustó', true);
  abierta(form, 'Si pudieras cambiar una sola cosa, ¿cuál sería?', true);
  abierta(form, '¿Algo más que quieras contarnos?');

  var hoja = SpreadsheetApp.create('Zero Depth: respuestas de la prueba');
  form.setDestination(FormApp.DestinationType.SPREADSHEET, hoja.getId());
  try {
    if (form.setPublished) form.setPublished(true);  // newer Google Forms need publishing to take answers
  } catch (e) {
    Logger.log('Publícalo a mano: abre el formulario y pulsa "Publicar".');
  }

  Logger.log('Enlace para tus amigos: ' + form.getPublishedUrl());
  Logger.log('Editar el formulario: ' + form.getEditUrl());
  Logger.log('Hoja de respuestas: ' + hoja.getUrl());
}

function seccion(form, titulo, ayuda) {
  form.addPageBreakItem().setTitle(titulo).setHelpText(ayuda);
}

function nota(form, titulo) {
  form.addScaleItem().setTitle(titulo).setBounds(1, 5).setLabels('Muy mal', 'Genial').setRequired(true);
}

function abierta(form, titulo, obligatoria) {
  form.addParagraphTextItem().setTitle(titulo).setRequired(!!obligatoria);
}

function opciones(form, titulo, lista, obligatoria) {
  form.addMultipleChoiceItem().setTitle(titulo).setChoiceValues(lista).setRequired(!!obligatoria);
}
