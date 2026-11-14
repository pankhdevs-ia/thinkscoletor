const API_URL = "https://script.google.com/macros/s/AKfycbz5rMscgiibL3OjlVEm71nxxnLQ65F_YyuQvlY3bJjG7tSgJK5-YJRbYDBTzvjwwEdjZA/exec";
let equipamentos = [];

const grid = document.getElementById("gridEquipamentos");
const filtroEmpresa = document.getElementById("filtroEmpresa");
const buscaTexto = document.getElementById("buscaTexto");

async function carregarDados() {
  grid.innerHTML = "<p>Carregando inventário...</p>";
  try {
    const res = await fetch(API_URL);
    equipamentos = await res.json();
    popularFiltroEmpresas();
    renderizarCards();
  } catch (err) {
    grid.innerHTML = `<p>Erro ao carregar dados: ${err}</p>`;
  }
}

function popularFiltroEmpresas() {
  const empresas = [...new Set(equipamentos.map(e => e.Empresa).filter(Boolean))].sort();
  filtroEmpresa.innerHTML = '<option value="">Todas as Empresas / Clientes</option>';
  empresas.forEach(emp => {
    const opt = document.createElement("option");
    opt.value = emp;
    opt.textContent = emp;
    filtroEmpresa.appendChild(opt);
  });
}

function renderizarCards() {
  const empSelecionada = filtroEmpresa.value.toLowerCase();
  const termo = buscaTexto.value.toLowerCase();

  const filtrados = equipamentos.filter(item => {
    const matchEmp = !empSelecionada || (item.Empresa || "").toLowerCase() === empSelecionada;
    const textoItem = `${item.Hostname} ${item.SerialNumber} ${item.UsuarioAtual} ${item.FabricanteModelo} ${item.Setor}`.toLowerCase();
    const matchTexto = !termo || textoItem.includes(termo);
    return matchEmp && matchTexto;
  });

  grid.innerHTML = filtrados.map(item => `
    <div class="card">
      <div>
        <div class="card-header">
          <div>
            <strong>${item.Hostname}</strong> (${item.TipoDispositivo})<br>
            <small style="color:#94a3b8">${item.Empresa} • ${item.Setor}</small>
          </div>
          <span class="badge">${item.SSDStatus || "Disco OK"}</span>
        </div>
        <p><strong>Modelo:</strong> ${item.FabricanteModelo}</p>
        <p><strong>Serial:</strong> ${item.SerialNumber}</p>
        <p><strong>CPU:</strong> ${item.CPU}</p>
        <p><strong>RAM:</strong> ${item.RAMTotalGB} GB ${item.RAMTipo} (${item.RAMFreqMHz} MHz) - Uso: ${item.RAMUsoPct}%</p>
        <p><strong>GPU:</strong> ${item.GPU}</p>
        <p><strong>Disco C:</strong> ${item.C_UsadoGB}GB / ${item.C_TotalGB}GB (Livre: ${item.C_LivreGB}GB)</p>
        <p><strong>Rede:</strong> ${item.IP} | ${item.MAC}</p>
        <p><strong>Acesso:</strong> AD: ${item.AnyDesk} | TV: ${item.TeamViewer}</p>
        <p><strong>Atualizado:</strong> ${item.DataHora}</p>
        ${item.Observacoes ? `<p><strong>Obs:</strong> ${item.Observacoes}</p>` : ""}
      </div>
      <div class="card-actions">
        <button class="btn-wpp" onclick="copiarWhatsApp('${item.SerialNumber}')">Copiar p/ WhatsApp</button>
        <button class="btn-edit" onclick="abrirEdicao('${item.SerialNumber}')">Editar</button>
      </div>
    </div>
  `).join("");
}

function copiarWhatsApp(serial) {
  const item = equipamentos.find(e => String(e.SerialNumber) === String(serial));
  if (!item) return;

  const texto = `💻 *RELATÓRIO DE EQUIPAMENTO*
🏢 *Empresa/Setor:* ${item.Empresa} - ${item.Setor}
🖥️ *Hostname:* ${item.Hostname} (${item.TipoDispositivo})
🏷️ *Modelo:* ${item.FabricanteModelo}
🔢 *Serial:* ${item.SerialNumber}
👤 *Usuário:* ${item.UsuarioAtual}

⚙️ *Hardware:*
• *CPU:* ${item.CPU}
• *RAM:* ${item.RAMTotalGB} GB ${item.RAMTipo} (${item.RAMFreqMHz} MHz)
• *GPU:* ${item.GPU}
• *Armazenamento:* Disco ${item.DiscoFisicoGB} GB | C: ${item.C_LivreGB} GB livres de ${item.C_TotalGB} GB
• *Saúde SSD:* ${item.SSDStatus}

🌐 *Rede & Sistema:*
• *SO:* ${item.SO}
• *IP / MAC:* ${item.IP} | ${item.MAC}

🛠️ *Suporte Remoto:*
• *AnyDesk:* ${item.AnyDesk}
• *TeamViewer:* ${item.TeamViewer}

🕒 _Coletado em: ${item.DataHora}_`;

  navigator.clipboard.writeText(texto).then(() => {
    alert("Especificações copiadas! Cole no WhatsApp.");
  });
}

// Lógica de Edição
const modal = document.getElementById("modalEditar");
function abrirEdicao(serial) {
  const item = equipamentos.find(e => String(e.SerialNumber) === String(serial));
  document.getElementById("editSerialTitle").textContent = item.SerialNumber;
  document.getElementById("editSerial").value = item.SerialNumber;
  document.getElementById("editEmpresa").value = item.Empresa;
  document.getElementById("editSetor").value = item.Setor;
  document.getElementById("editUsuario").value = item.UsuarioAtual;
  document.getElementById("editAnyDesk").value = item.AnyDesk;
  document.getElementById("editObs").value = item.Observacoes || "";
  modal.classList.remove("hidden");
}

document.getElementById("btnFecharModal").onclick = () => modal.classList.add("hidden");

document.getElementById("formEditar").onsubmit = async (e) => {
  e.preventDefault();
  const payload = {
    SerialNumber: document.getElementById("editSerial").value,
    Empresa: document.getElementById("editEmpresa").value,
    Setor: document.getElementById("editSetor").value,
    UsuarioAtual: document.getElementById("editUsuario").value,
    AnyDesk: document.getElementById("editAnyDesk").value,
    Observacoes: document.getElementById("editObs").value
  };

  await fetch(API_URL, {
    method: "POST",
    body: JSON.stringify(payload)
  });

  modal.classList.add("hidden");
  carregarDados();
};

filtroEmpresa.onchange = renderizarCards;
buscaTexto.oninput = renderizarCards;
document.getElementById("btnAtualizar").onclick = carregarDados;

carregarDados();