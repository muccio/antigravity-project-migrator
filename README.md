# 🚀 Antigravity Project Migrator

**Antigravity Project Migrator** è un'applicazione macOS nativa e standalone (scritta in Swift / SwiftUI) progettata appositamente per gestire, dimensionare e spostare i progetti di sviluppo su dischi esterni o SSD **senza perdere la cronologia delle chat, i contesti storici o i piani di lavoro di Google Antigravity**.

---

## 🌟 Caratteristiche Principali

- 📊 **Scansione e Analisi Dimensioni**:
  - Elenca tutti i progetti presenti in una cartella scelta (es. `~/Documents/Development/WEBDEV`).
  - Calcola la dimensione effettiva occupata da ciascun progetto sul disco.
  - Rileva e quantifica le cartelle di cache ricreabili (`node_modules`, `build`, `dist`, `target`, `.next`, etc.).

- 💬 **Integrazione Database Antigravity**:
  - Si connette direttamente al database delle conversazioni (`~/.gemini/antigravity/conversation_summaries.db`) e allo stato di VS Code (`state.vscdb`).
  - Indica esattamente quante chat e sessioni di pair programming sono collegate a ciascun progetto.

- 🛡️ **Migrazione Sicura su Disco Esterno (Senza Effetti su Antigravity)**:
  - **Metodo Trasparente (Symlink)**: Copia i file fisici sull'unità esterna e crea un collegamento simbolico identico (`ln -s`) nel percorso originale. In questo modo Antigravity trova sempre i file allo stesso percorso assoluto, mantenendo intatte tutte le chat e i piani.
  - **Verifica Processi**: Controlla se Antigravity o `agy` sono aperti prima dello spostamento, con pulsante per chiudere l'app in sicurezza.
  - **Backup Automatico delle Chat**: Crea una copia di sicurezza timestampata dei database prima del trasferimento in `~/.gemini/antigravity_backups/`.
  - **Controllo Filesystem (APFS vs ExFAT)**: Riconosce il file system del disco esterno e avvisa l'utente se l'unità è formattata in ExFAT (consigliando APFS per preservare permessi POSIX e symlink di Git/node).
  - **Sfoltimento Cache Opzionale**: Permette di eliminare `node_modules` e build prima della copia per velocizzare drasticamente il trasferimento.
  - **Trasferimento Atomico e Rollback**: Usa `rsync -avP --protect-args`, verifica l'integrità dei dati copiati e, in caso di problemi, ripristina la cartella originale senza perdite.

- 🔄 **Ripristino sul Mac ("Ripristina sul Mac")**:
  - Se un progetto è già stato spostato su disco esterno, puoi riportarlo sulla memoria interna del Mac con un solo clic.

---

## 🖥️ Come Avviare l'Applicazione

Puoi avviare l'applicazione in due modi:

1. **Dal Finder**:
   Fai doppio clic su `Antigravity Migrator.app` presente in questa cartella (puoi anche trascinarla nella cartella `/Applications` del tuo Mac).

2. **Da Terminale**:
   ```bash
   open "/Users/mariosalvucci/Documents/Development/WEBDEV/_PROJECT_MIGRATION/Antigravity Migrator.app"
   ```

---

## 🛠️ Come Ricompilare l'Applicazione

Lo script di compilazione autonomo si trova in `scripts/build_app.sh`:
```bash
./scripts/build_app.sh
```
Questo script compila tutti i sorgenti Swift in un binario nativo ARM64 ottimizzato e applica la firma del codice per macOS.

---

## 📂 Struttura del Progetto

```
_PROJECT_MIGRATION/
├── Antigravity Migrator.app/      # Applicazione macOS Standalone pronta all'uso
├── src/
│   ├── App.swift                  # Entry point SwiftUI
│   ├── Models/
│   │   ├── ProjectItem.swift      # Modello dati progetto, stato e percorsi
│   │   ├── ExternalVolume.swift   # Rilevamento dischi esterni e filesystem
│   │   └── CacheFolderItem.swift  # Dettaglio cartelle node_modules/build
│   ├── Services/
│   │   ├── AntigravityService.swift # Interrogazione SQLite e backup chat
│   │   ├── ProcessService.swift     # Rilevamento e arresto sicuro di Antigravity
│   │   ├── VolumeService.swift      # Ispezione volumi (/Volumes/*, APFS/ExFAT)
│   │   ├── FolderSizeService.swift  # Calcolo veloce dimensioni e pulizia cache
│   │   ├── FolderScanner.swift      # Scansione asincrona dei progetti
│   │   └── MigrationService.swift   # Motore di copia rsync, verifica e symlink
│   ├── Views/
│   │   ├── MainWindowView.swift     # Finestra principale con split view e filtri
│   │   ├── ProjectRowView.swift     # Elemento della lista progetti
│   │   ├── ProjectDetailView.swift  # Pannello laterale dettagli e azioni
│   │   ├── MigrationModalView.swift # Wizard guidato di spostamento
│   │   ├── RestoreModalView.swift   # Ripristino da disco esterno a Mac
│   │   ├── CleanCacheModalView.swift# Pulizia selettiva cache
│   │   └── BackupsModalView.swift   # Gestione backup chat di sicurezza
│   └── Resources/
│       ├── Info.plist
│       └── AppIcon.icns             # Icona vettoriale alta risoluzione 1024x1024
└── scripts/
    ├── build_app.sh                 # Script di compilazione nativa
    └── create_icon.py               # Generatore icona macOS
```
