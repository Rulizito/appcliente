// ============================================================================
// Firebase Cloud Functions para enviar notificaciones push Y pagos
// Archivo: functions/index.js
// ============================================================================

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { MercadoPagoConfig, Preference } = require('mercadopago');

admin.initializeApp();

// ============================================================================
// CONFIGURACIÓN DE MERCADO PAGO
// ============================================================================

// 🔥 IMPORTANTE: Reemplaza esto con tu Access Token real
// Para testing: usa tu token de prueba (TEST-...)
// Para producción: usa tu token real
const MP_ACCESS_TOKEN = 'TEST-8797016397732991-122600-fd6a823aee189b1775f8ed4ca002cc8b-744210964'; // ⚠️ CAMBIAR ESTO

const client = new MercadoPagoConfig({
  accessToken: MP_ACCESS_TOKEN,
});

// ============================================================================
// FUNCIÓN PARA CREAR PREFERENCIA DE PAGO (MERCADO PAGO)
// ============================================================================

exports.createPaymentPreference = functions.https.onCall(async (data, context) => {
  // Verificar que el usuario esté autenticado
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'El usuario debe estar autenticado'
    );
  }

  const { orderId, amount, description } = data;

  // Validar datos
  if (!orderId || !amount || !description) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Faltan datos requeridos: orderId, amount, description'
    );
  }

  try {
    console.log(`💰 Creando preferencia de pago para pedido ${orderId}`);

    const preference = new Preference(client);

    // 🔥 AQUÍ VA TU URL - Más abajo te explico cómo obtenerla
    const WEBHOOK_URL = 'https://us-central1-delivery-app-9a543.cloudfunctions.net/mercadoPagoWebhook';

    const preferenceData = {
      items: [
        {
          title: description,
          quantity: 1,
          unit_price: amount,
          currency_id: 'ARS', // Peso argentino
        }
      ],
      back_urls: {
        success: 'https://tu-app.com/payment-success',
        failure: 'https://tu-app.com/payment-failure',
        pending: 'https://tu-app.com/payment-pending',
      },
      auto_return: 'approved',
      external_reference: orderId, // Para identificar el pedido
      notification_url: WEBHOOK_URL, // ⚠️ Webhook para recibir notificaciones
    };

    const result = await preference.create({ body: preferenceData });

    console.log('✅ Preferencia creada exitosamente');
    
    return {
      success: true,
      preferenceId: result.id,
      initPoint: result.init_point, // URL para abrir checkout
    };

  } catch (error) {
    console.error('❌ Error al crear preferencia:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Error al crear la preferencia de pago',
      error.message
    );
  }
});

// ============================================================================
// WEBHOOK PARA RECIBIR NOTIFICACIONES DE MERCADO PAGO
// ============================================================================

exports.mercadoPagoWebhook = functions.https.onRequest(async (req, res) => {
  console.log('🔔 Webhook recibido de Mercado Pago');
  console.log('Tipo:', req.body.type);
  console.log('Datos:', JSON.stringify(req.body));

  // Mercado Pago envía notificaciones de tipo "payment"
  if (req.body.type === 'payment') {
    const paymentId = req.body.data.id;

    try {
      // Aquí puedes consultar el estado del pago usando la API de MP
      // y actualizar el pedido en Firestore según el resultado
      
      console.log(`💳 Pago recibido: ${paymentId}`);
      
      // TODO: Consultar estado del pago y actualizar pedido
      // const payment = await mercadopago.payment.get(paymentId);
      // await admin.firestore().collection('orders').doc(orderId).update({
      //   paymentStatus: payment.status,
      //   paymentId: paymentId
      // });

      res.status(200).send('OK');
    } catch (error) {
      console.error('❌ Error procesando webhook:', error);
      res.status(500).send('Error');
    }
  } else {
    res.status(200).send('OK');
  }
});

// ============================================================================
// FUNCIONES PARA NOTIFICACIONES DE PEDIDOS
// ============================================================================

// Función que se ejecuta cuando cambia el estado de un pedido
exports.sendOrderStatusNotification = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const orderBefore = change.before.data();
    const orderAfter = change.after.data();
    const orderId = context.params.orderId;

    // Verificar si el estado cambió
    if (orderBefore.status === orderAfter.status) {
      console.log('El estado no cambió, no se envía notificación');
      return null;
    }

    console.log(`Estado cambió de ${orderBefore.status} a ${orderAfter.status}`);

    // Obtener el token FCM del usuario
    const userId = orderAfter.userId;
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();

    if (!userDoc.exists) {
      console.log('Usuario no encontrado');
      return null;
    }

    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;

    if (!fcmToken) {
      console.log('Usuario no tiene token FCM');
      return null;
    }

    // Construir el mensaje según el estado
    const { title, body } = getNotificationContent(
      orderAfter.status,
      orderAfter.businessName,
      orderId
    );

    // Preparar el mensaje de notificación
    const message = {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        orderId: orderId,
        status: orderAfter.status,
        type: 'order_update',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'delivery_orders_channel',
          sound: 'default',
          color: '#FF0000',
          icon: '@mipmap/ic_launcher',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    try {
      // Enviar la notificación
      const response = await admin.messaging().send(message);
      console.log('Notificación enviada exitosamente:', response);
      return response;
    } catch (error) {
      console.error('Error al enviar notificación:', error);
      return null;
    }
  });

// Función cuando se crea un nuevo pedido
exports.sendNewOrderNotification = functions.firestore
  .document('orders/{orderId}')
  .onCreate(async (snap, context) => {
    const order = snap.data();
    const orderId = context.params.orderId;
    const userId = order.userId;

    console.log(`Nuevo pedido creado: ${orderId}`);

    // Obtener token del usuario
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();

    if (!userDoc.exists) {
      return null;
    }

    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;

    if (!fcmToken) {
      return null;
    }

    const message = {
      token: fcmToken,
      notification: {
        title: '🎉 ¡Pedido recibido!',
        body: `Tu pedido en ${order.businessName} ha sido recibido. Te avisaremos cuando sea confirmado.`,
      },
      data: {
        orderId: orderId,
        status: 'pending',
        type: 'order_created',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'delivery_orders_channel',
          sound: 'default',
          color: '#FF0000',
        },
      },
    };

    try {
      const response = await admin.messaging().send(message);
      console.log('Notificación de nuevo pedido enviada:', response);
      return response;
    } catch (error) {
      console.error('Error al enviar notificación:', error);
      return null;
    }
  });

// Función auxiliar para obtener el contenido de la notificación según el estado
function getNotificationContent(status, businessName, orderId) {
  const orderNumber = orderId.substring(0, 8);
  
  switch (status) {
    case 'confirmed':
      return {
        title: '✅ Pedido confirmado',
        body: `${businessName} confirmó tu pedido #${orderNumber}`,
      };
    
    case 'preparing':
      return {
        title: '👨‍🍳 Preparando tu pedido',
        body: `${businessName} está preparando tu pedido #${orderNumber}`,
      };
    
    case 'ready_for_pickup':
      return {
        title: '📦 Pedido listo',
        body: `Tu pedido #${orderNumber} está listo y esperando al repartidor`,
      };
    
    case 'on_way':
      return {
        title: '🚴 En camino',
        body: `Tu pedido #${orderNumber} viene en camino. ¡Llegará pronto!`,
      };
    
    case 'delivered':
      return {
        title: '🎊 ¡Pedido entregado!',
        body: `Tu pedido #${orderNumber} fue entregado. ¡Disfrutalo!`,
      };
    
    case 'cancelled':
      return {
        title: '❌ Pedido cancelado',
        body: `Tu pedido #${orderNumber} en ${businessName} fue cancelado`,
      };
    
    default:
      return {
        title: 'Actualización de pedido',
        body: `Tu pedido #${orderNumber} fue actualizado`,
      };
  }
}

// ============================================================================
// FUNCIONES PARA NOTIFICACIONES DE CHAT
// ============================================================================

// Función que se ejecuta cuando soporte envía un mensaje
exports.sendChatNotification = functions.firestore
  .document('support_conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const conversationId = context.params.conversationId;
    const messageId = context.params.messageId;

    console.log(`💬 Nuevo mensaje en conversación ${conversationId}`);

    // Solo enviar notificación si el mensaje es del soporte
    if (message.senderType !== 'support') {
      console.log('❌ Mensaje del cliente, no se envía notificación');
      return null;
    }

    console.log('✅ Mensaje del soporte, enviando notificación...');

    // Obtener la conversación para obtener el userId
    const conversationDoc = await admin.firestore()
      .collection('support_conversations')
      .doc(conversationId)
      .get();

    if (!conversationDoc.exists) {
      console.log('❌ Conversación no encontrada');
      return null;
    }

    const conversation = conversationDoc.data();
    const userId = conversation.userId;

    // Obtener el token FCM del usuario
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();

    if (!userDoc.exists) {
      console.log('❌ Usuario no encontrado');
      return null;
    }

    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;

    if (!fcmToken) {
      console.log('❌ Usuario no tiene token FCM');
      return null;
    }

    console.log(`📱 Enviando notificación a token: ${fcmToken.substring(0, 20)}...`);

    // 🔥 CORRECCIÓN AQUÍ - LÍNEA 450 (antes era línea 283)
    // ANTES: message.text
    // AHORA: message.message
    const notificationMessage = {
      token: fcmToken,
      notification: {
        title: '💬 Equipo de Soporte',
        body: message.message || 'Te han enviado un mensaje',  // ✅ CORREGIDO
      },
      data: {
        type: 'chat_message',
        conversationId: conversationId,
        messageId: messageId,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'chat_channel',
          sound: 'default',
          color: '#4CAF50',
          icon: '@mipmap/ic_launcher',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    try {
      const response = await admin.messaging().send(notificationMessage);
      console.log('✅ Notificación de chat enviada exitosamente:', response);
      return response;
    } catch (error) {
      console.error('❌ Error al enviar notificación de chat:', error);
      return null;
    }
  });

// Función para procesar cola de notificaciones (opcional, para uso futuro)
exports.processNotificationQueue = functions.firestore
  .document('notifications_queue/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    const notificationId = context.params.notificationId;

    console.log(`📋 Procesando notificación en cola: ${notificationId}`);

    // Verificar que la notificación no haya sido procesada
    if (notification.processed) {
      console.log('⏭️ Notificación ya procesada, saltando...');
      return null;
    }

    const fcmToken = notification.fcmToken;
    if (!fcmToken) {
      console.log('❌ No hay token FCM en la notificación');
      return null;
    }

    // Construir el mensaje
    const message = {
      token: fcmToken,
      notification: {
        title: notification.title || 'Notificación',
        body: notification.body || '',
      },
      data: notification.data || {},
      android: {
        priority: 'high',
        notification: {
          channelId: notification.channelId || 'default_channel',
          sound: 'default',
        },
      },
    };

    try {
      const response = await admin.messaging().send(message);
      console.log('✅ Notificación de cola enviada:', response);

      // Marcar como procesada
      await snap.ref.update({
        processed: true,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        response: response,
      });

      return response;
    } catch (error) {
      console.error('❌ Error al procesar notificación de cola:', error);

      // Registrar el error en el documento
      await snap.ref.update({
        processed: true,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        error: error.message,
      });

      return null;
    }
  });

// ============================================================================
// FUNCIONES DE LIMPIEZA AUTOMÁTICA
// ============================================================================

// Función para limpiar tokens inválidos
exports.cleanupInvalidTokens = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    console.log('Limpiando tokens FCM inválidos...');
    
    // Esta función se ejecutará diariamente para limpiar tokens que ya no son válidos
    // Por ahora solo registra, pero podrías implementar la lógica de limpieza
    
    return null;
  });

// Función para limpiar notificaciones antiguas de la cola
exports.cleanOldNotifications = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    console.log('🧹 Limpiando notificaciones antiguas...');

    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    const snapshot = await admin.firestore()
      .collection('notifications_queue')
      .where('processed', '==', true)
      .where('processedAt', '<', sevenDaysAgo)
      .get();

    if (snapshot.empty) {
      console.log('✨ No hay notificaciones antiguas para limpiar');
      return null;
    }

    console.log(`🗑️ Eliminando ${snapshot.size} notificaciones antiguas`);

    const batch = admin.firestore().batch();
    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();
    console.log('✅ Notificaciones antiguas eliminadas');

    return null;
  });