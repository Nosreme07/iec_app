const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

// O Robô vigia a coleção 'notices'. 
// Quando um novo documento é criado, ele dispara.
exports.enviarNotificacao = onDocumentCreated("notices/{docId}", async (event) => {
    
    // Na V2, o 'snap' fica dentro de event.data
    const snap = event.data;
    
    // Se por algum motivo o documento não existir, para aqui
    if (!snap) {
        console.log("Nenhum dado encontrado");
        return;
    }

    const data = snap.data();
    const titulo = data.title;
    const mensagem = data.body;

    // Configuração da mensagem
    const payload = {
        notification: {
            title: titulo,
            body: mensagem,
        },
        topic: 'todos' // Envia para quem se inscreveu em 'todos'
    };

    // Envia usando a API Segura do Admin SDK
    try {
        const response = await admin.messaging().send(payload);
        console.log('Notificação enviada com sucesso:', response);
    } catch (error) {
        console.error('Erro ao enviar notificação:', error);
    }
});