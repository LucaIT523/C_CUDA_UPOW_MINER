
// InfoLicenseDlg.cpp : implementation file
//

#include "pch.h"
#include "framework.h"
#include "InfoLicense.h"
#include "InfoLicenseDlg.h"
#include "afxdialogex.h"
#include "license.h"
#include "ThemidaSDK.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#endif

#define			DEV_MAX_CNT			24

// CAboutDlg dialog used for App About

class CAboutDlg : public CDialogEx
{
public:
	CAboutDlg();

// Dialog Data
#ifdef AFX_DESIGN_TIME
	enum { IDD = IDD_ABOUTBOX };
#endif

	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support

// Implementation
protected:
	DECLARE_MESSAGE_MAP()
};

CAboutDlg::CAboutDlg() : CDialogEx(IDD_ABOUTBOX)
{
}

void CAboutDlg::DoDataExchange(CDataExchange* pDX)
{
	CDialogEx::DoDataExchange(pDX);
}

BEGIN_MESSAGE_MAP(CAboutDlg, CDialogEx)
END_MESSAGE_MAP()


// CInfoLicenseDlg dialog



CInfoLicenseDlg::CInfoLicenseDlg(CWnd* pParent /*=nullptr*/)
	: CDialogEx(IDD_INFOLICENSE_DIALOG, pParent)
{
	m_hIcon = AfxGetApp()->LoadIcon(IDR_MAINFRAME);
}

void CInfoLicenseDlg::DoDataExchange(CDataExchange* pDX)
{
	CDialogEx::DoDataExchange(pDX);
	DDX_Control(pDX, IDC_COMBO_DEVICE_LIST, m_ctrlDeviceList);
}

BEGIN_MESSAGE_MAP(CInfoLicenseDlg, CDialogEx)
	ON_WM_SYSCOMMAND()
	ON_WM_PAINT()
	ON_WM_QUERYDRAGICON()
	ON_BN_CLICKED(IDOK, &CInfoLicenseDlg::OnBnClickedOk)
	ON_BN_CLICKED(IDCANCEL, &CInfoLicenseDlg::OnBnClickedCancel)
END_MESSAGE_MAP()


// CInfoLicenseDlg message handlers

BOOL CInfoLicenseDlg::OnInitDialog()
{
	CDialogEx::OnInitDialog();

	// Add "About..." menu item to system menu.

	// IDM_ABOUTBOX must be in the system command range.
	ASSERT((IDM_ABOUTBOX & 0xFFF0) == IDM_ABOUTBOX);
	ASSERT(IDM_ABOUTBOX < 0xF000);

	CMenu* pSysMenu = GetSystemMenu(FALSE);
	if (pSysMenu != nullptr)
	{
		BOOL bNameValid;
		CString strAboutMenu;
		bNameValid = strAboutMenu.LoadString(IDS_ABOUTBOX);
		ASSERT(bNameValid);
		if (!strAboutMenu.IsEmpty())
		{
			pSysMenu->AppendMenu(MF_SEPARATOR);
			pSysMenu->AppendMenu(MF_STRING, IDM_ABOUTBOX, strAboutMenu);
		}
	}

	// Set the icon for this dialog.  The framework does this automatically
	//  when the application's main window is not a dialog
	SetIcon(m_hIcon, TRUE);			// Set big icon
	SetIcon(m_hIcon, FALSE);		// Set small icon

	int			w_nSts = -1;
	USES_CONVERSION;
	for (int i = 0; i < DEV_MAX_CNT; i++) {
		char		w_szDeviceInfo[256] = { 0, };
		char		w_szDeviceHead[256] = { 0, };

		w_nSts = getDeviceInfo(w_szDeviceInfo, i, w_szDeviceHead);
		if (w_nSts == 0) {
			m_ctrlDeviceList.InsertString(i, A2T(w_szDeviceHead));
		}
		else {
			break;
		}
	}

	if (m_ctrlDeviceList.GetCount() > 0) {
		m_ctrlDeviceList.SetCurSel(0);
	}

	return TRUE;  // return TRUE  unless you set the focus to a control
}

void CInfoLicenseDlg::OnSysCommand(UINT nID, LPARAM lParam)
{
	if ((nID & 0xFFF0) == IDM_ABOUTBOX)
	{
		CAboutDlg dlgAbout;
		dlgAbout.DoModal();
	}
	else
	{
		CDialogEx::OnSysCommand(nID, lParam);
	}
}

// If you add a minimize button to your dialog, you will need the code below
//  to draw the icon.  For MFC applications using the document/view model,
//  this is automatically done for you by the framework.

void CInfoLicenseDlg::OnPaint()
{
	if (IsIconic())
	{
		CPaintDC dc(this); // device context for painting

		SendMessage(WM_ICONERASEBKGND, reinterpret_cast<WPARAM>(dc.GetSafeHdc()), 0);

		// Center icon in client rectangle
		int cxIcon = GetSystemMetrics(SM_CXICON);
		int cyIcon = GetSystemMetrics(SM_CYICON);
		CRect rect;
		GetClientRect(&rect);
		int x = (rect.Width() - cxIcon + 1) / 2;
		int y = (rect.Height() - cyIcon + 1) / 2;

		// Draw the icon
		dc.DrawIcon(x, y, m_hIcon);
	}
	else
	{
		CDialogEx::OnPaint();
	}
}

// The system calls this function to obtain the cursor to display while the user drags
//  the minimized window.
HCURSOR CInfoLicenseDlg::OnQueryDragIcon()
{
	return static_cast<HCURSOR>(m_hIcon);
}



void CInfoLicenseDlg::OnBnClickedOk()
{
	VM_TIGER_WHITE_START
		
	int			w_nSts = -1;
	char		w_szDeviceInfo[256] = { 0, };
	char		w_szDeviceHead[256] = { 0, };
	FILE*		w_pFile = NULL;
	BYTE		w_bOutData[32] = { 0, };
	TCHAR		w_szFilePath[MAX_PATH] = L"";
	UPOW_LICENSE_INFO	w_stLICENSE_INFO;

	memset(&w_stLICENSE_INFO, 0x00, sizeof(UPOW_LICENSE_INFO));
	w_nSts = getDeviceInfo(w_szDeviceInfo, m_ctrlDeviceList.GetCurSel(), w_szDeviceHead);
	if (w_nSts != 0) {
		AfxMessageBox(L"Error ... getDeviceInfo");
		goto L_EXIT;
	}

	w_nSts = getHashInfo((BYTE*)w_szDeviceInfo, strlen(w_szDeviceInfo), w_stLICENSE_INFO.m_bData);
	if (w_nSts != 0) {
		AfxMessageBox(L"Error ... setLicenseInfo");
		goto L_EXIT;
	}

	srand(time(NULL));


	USES_CONVERSION;
	int random = rand() % 9999;
	swprintf(w_szFilePath, L"./%s-%d", A2T(w_szDeviceHead), random);
	w_pFile = _tfopen(w_szFilePath, L"wb");
	if (w_pFile == NULL) {
		AfxMessageBox(L"Error ... file open");
		goto L_EXIT;
	}
	strcpy(w_stLICENSE_INFO.m_szDeviceHead, w_szDeviceHead);
	fwrite(&w_stLICENSE_INFO, 1, sizeof(UPOW_LICENSE_INFO), w_pFile);
	fclose(w_pFile);

	//. OK
	swprintf(w_szFilePath, L"OK ... %s-%d", A2T(w_szDeviceHead), random);
	AfxMessageBox(w_szFilePath,  MB_OK);


L_EXIT:
	VM_TIGER_WHITE_END
	return;
}


void CInfoLicenseDlg::OnBnClickedCancel()
{
	EndDialog(IDCANCEL);
}
