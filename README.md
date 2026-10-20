# Tripper Pilot iOS

Protótipo pessoal para conectar um iPhone ao Royal Enfield Tripper Pod pequeno (`RE_DISP`) por Bluetooth Low Energy.

## Estado atual

Esta primeira versão é deliberadamente diagnóstica. Ela:

- procura o serviço BLE conhecido do Tripper Pod;
- conecta ao dispositivo `RE_DISP`;
- publica no iPhone o serviço GATT de retorno esperado pelo Pod;
- permite iniciar o pareamento, enviar o PIN e retomar um dispositivo conhecido;
- envia keepalive a cada dois segundos;
- registra os pacotes transmitidos e recebidos na tela;
- opta por restauração de estado e reconexão automática do Core Bluetooth.

A bússola, alertas, RPM e TPMS serão adicionados depois que a conexão e o handshake forem confirmados no hardware real.

## Gerar o IPA gratuitamente

1. Envie estes arquivos para a branch `main` do GitHub. No Windows, abra PowerShell nesta pasta e execute `./publicar-no-github.ps1`; o Git poderá abrir o navegador para você entrar no GitHub.
2. Abra **Actions** no repositório.
3. Execute **Build unsigned IPA** ou faça um novo commit.
4. Ao terminar, abra a execução e baixe o artefato `TripperPilot-unsigned`.
5. Extraia o ZIP para obter `TripperPilot-unsigned.ipa`.
6. No Windows, instale o AltServer/AltStore e use **Sideload .ipa** para instalar o arquivo no iPhone.

O aplicativo instalado com uma conta Apple gratuita precisa ser renovado a cada sete dias.

## Primeiro teste na moto

1. Deixe o iPhone desbloqueado, Bluetooth ligado e o aplicativo aberto.
2. Ligue a ignição da moto.
3. Toque em **Buscar e conectar** imediatamente; o Pod anuncia por uma janela curta.
4. Quando o status indicar que o canal está pronto, toque em **Iniciar pareamento**.
5. Digite no aplicativo o PIN mostrado no Tripper e toque em **Enviar PIN**.
6. Copie os eventos exibidos se ocorrer alguma falha.

Configure tudo com a motocicleta parada. Não opere o aplicativo enquanto estiver pilotando.

## Base técnica

O protocolo implementado nesta fase segue a documentação comunitária do projeto WazeTripper. Não é uma especificação oficial da Royal Enfield.

